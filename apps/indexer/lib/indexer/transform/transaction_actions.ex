defmodule Indexer.Transform.TransactionActions do
  @moduledoc """
  Helper functions for transforming data for transaction actions.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias ABI.TypeDecoder
  alias Explorer.Chain.Cache.NetVersion
  alias Explorer.Chain.{Hash, Token, TransactionActions}
  alias Explorer.Repo
  alias Explorer.SmartContract.Reader

  @mainnet 1
  @optimism 10
  @polygon 137
  @gnosis 100

  @null_address "0x0000000000000000000000000000000000000000"
  @uniswap_v3_positions_nft "0xc36442b4a4522e871399cd717abdd847ab11fe88"
  @uniswap_v3_factory "0x1f98431c8ad98523631ae4a59f267346ea31f984"
  @uniswap_v3_factory_abi [
    %{
      "inputs" => [
        %{"internalType" => "address", "name" => "", "type" => "address"},
        %{"internalType" => "address", "name" => "", "type" => "address"},
        %{"internalType" => "uint24", "name" => "", "type" => "uint24"}
      ],
      "name" => "getPool",
      "outputs" => [%{"internalType" => "address", "name" => "", "type" => "address"}],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]
  @uniswap_v3_pool_abi [
    %{
      "inputs" => [],
      "name" => "fee",
      "outputs" => [%{"internalType" => "uint24", "name" => "", "type" => "uint24"}],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "token0",
      "outputs" => [%{"internalType" => "address", "name" => "", "type" => "address"}],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [],
      "name" => "token1",
      "outputs" => [%{"internalType" => "address", "name" => "", "type" => "address"}],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]
  @erc20_abi [%{"constant"=>true,"inputs"=>[],"name"=>"symbol","outputs"=>[%{"name"=>"","type"=>"string"}],"payable"=>false,"stateMutability"=>"view","type"=>"function"},%{"constant"=>true,"inputs"=>[],"name"=>"decimals","outputs"=>[%{"name"=>"","type"=>"uint8"}],"payable"=>false,"stateMutability"=>"view","type"=>"function"}]

  @doc """
  Returns a list of transaction actions given a list of logs.
  """
  def parse(logs) do
    actions = []

    chain_id = NetVersion.get_version()

    logs
    |> logs_group_by_txs()
    |> clear_actions()

    # handle uniswap v3
    actions =
      if Enum.member?([@mainnet, @optimism, @polygon], chain_id) do
        logs
        |> uniswap_filter_logs()
        |> logs_group_by_txs()
        |> uniswap(actions, chain_id)
      else
        actions
      end

    %{transaction_actions: actions}
  end

  defp uniswap(logs_grouped, actions, chain_id) do
    # create a list of UniswapV3Pool legitimate contracts
    legitimate = uniswap_legitimate_pools(logs_grouped)

    # create tokens cache if not exists
    if :ets.whereis(:tokens_data_cache) == :undefined do
      :ets.new(:tokens_data_cache, [:named_table, :private])
    end

    # iterate for each transaction
    Enum.reduce(logs_grouped, actions, fn {tx_hash, tx_logs}, actions_acc ->
      # iterate for all logs of the transaction
      mint_nft_ids =
        Enum.reduce(tx_logs, %{}, fn log, acc ->
          first_topic = String.downcase(log.first_topic)

          if first_topic == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" do
            # This is Transfer event for NFT
            from = truncate_address_hash(log.second_topic)

            if from == "0x0000000000000000000000000000000000000000" do
              to = truncate_address_hash(log.third_topic)
              [tokenId] = decode_data(log.fourth_topic, [{:uint, 256}])

              mint_nft_ids =
                if not Map.has_key?(acc, to) do
                  Map.put(acc, to, [])
                else
                  acc
                end

              Map.put(mint_nft_ids, to, mint_nft_ids[to] ++ [to_string(tokenId)])
            else
              acc
            end
          else
            acc
          end
        end)

      actions_acc =
        Enum.reduce(mint_nft_ids, actions_acc, fn {to, ids}, acc ->
          acc ++ [%{
            hash: tx_hash,
            protocol: "uniswap_v3",
            data: %{
              name: "Uniswap V3: Positions NFT",
              symbol: "UNI-V3-POS",
              address: @uniswap_v3_positions_nft,
              to: to,
              ids: ids
            },
            type: "mint_nft"
          }]
        end)

      # go through other actions
      Enum.reduce(tx_logs, actions_acc, fn log, acc ->
        first_topic = String.downcase(log.first_topic)

        if first_topic == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" do
          acc
        else
          # check UniswapV3Pool contract is legitimate
          pool_address = String.downcase(log.address_hash)

          if Enum.count(legitimate[pool_address]) == 0 do
            # this is not legitimate uniswap pool, so skip this event
            acc
          else
            token_address = legitimate[pool_address]

            # try to read token symbols and decimals from the cache
            token_data =
              token_address
              |> Enum.reduce(%{}, fn address, token_data_acc ->
                Map.put(token_data_acc, address, get_token_data_from_cache(address))
              end)

            # a list of token addresses which we should select from the database
            select_tokens_from_db =
              token_data
              |> Enum.reduce([], fn {address, data}, select ->
                if is_nil(data.symbol) or is_nil(data.decimals) do
                  select ++ [address]
                else
                  select
                end
              end)

            token_data =
              if Enum.count(select_tokens_from_db) == 0 do
                token_data
              else
                # try to read token symbols and decimals from the database and then save to the cache
                query = from(
                  t in Token,
                  where: t.contract_address_hash in ^select_tokens_from_db,
                  select: {t.symbol, t.decimals, t.contract_address_hash}
                )

                query
                |> Repo.all()
                |> Enum.reduce(token_data, fn {symbol, decimals, contract_address_hash}, token_data_acc ->
                  contract_address_hash = String.downcase(Hash.to_string(contract_address_hash))

                  symbol =
                    if is_nil(symbol) or symbol == "" do
                      # if db field is empty, take it from the cache
                      token_data_acc[contract_address_hash].symbol
                    else
                      symbol
                    end

                  decimals =
                    if is_nil(decimals) do
                      # if db field is empty, take it from the cache
                      token_data_acc[contract_address_hash].decimals
                    else
                      decimals
                    end

                  new_data = %{symbol: symbol, decimals: decimals}

                  :ets.insert(:tokens_data_cache, {contract_address_hash, new_data})

                  Map.put(token_data_acc, contract_address_hash, new_data)
                end)
              end

            # if tokens are not in the cache, nor in the DB, read them through RPC
            read_tokens_from_rpc = 
              token_data
              |> Enum.reduce([], fn {address, data}, read ->
                if is_nil(data.symbol) or data.symbol == "" or is_nil(data.decimals) do
                  read ++ [address]
                else
                  read
                end
              end)

            token_data =
              if Enum.count(read_tokens_from_rpc) == 0 do
                token_data
              else
                # try to read token symbols and decimals from RPC and then save to the cache
                requests =
                  read_tokens_from_rpc
                  |> Enum.map(fn token_contract_address ->
                    Enum.map(["95d89b41", "313ce567"], fn method_id ->
                      %{
                        contract_address: token_contract_address,
                        method_id: method_id,
                        args: []
                      }
                    end)
                  end)
                  |> List.flatten()

                max_retries = Application.get_env(:explorer, :token_functions_reader_max_retries)
                responses = read_contracts_with_retries(requests, @erc20_abi, max_retries)

                if Enum.count(requests) != Enum.count(responses) do
                  Logger.error(fn -> "Cannot read symbol and decimals of an ERC-20 token contract" end)
                  token_data
                else
                  Enum.zip(requests, responses)
                  |> Enum.reduce(token_data, fn {request, {_status, response} = _resp}, token_data_acc ->
                    response =
                      case response do
                        [item] -> item
                        items -> items
                      end

                    data = token_data_acc[request.contract_address]

                    new_data =
                      if atomized_key(request.method_id) == :symbol do
                        %{data | symbol: response}
                      else
                        %{data | decimals: response}
                      end

                    :ets.insert(:tokens_data_cache, {request.contract_address, new_data})

                    Map.put(token_data_acc, request.contract_address, new_data)
                  end)
                end
              end

            if Enum.any?(token_data, fn {_, token} -> is_nil(token.symbol) or token.symbol == "" or is_nil(token.decimals) end) do
              # token data is not available, so skip this event
              acc
            else
              token0_symbol = uniswap_clarify_token_symbol(token_data[Enum.at(token_address, 0)].symbol, chain_id)
              token1_symbol = uniswap_clarify_token_symbol(token_data[Enum.at(token_address, 1)].symbol, chain_id)

              Logger.warn("token0_symbol = #{token0_symbol}")
              Logger.warn("token1_symbol = #{token1_symbol}")

              # todo

              acc
            end
          end
        end
      end)
    end)
  end

  defp uniswap_clarify_token_symbol(symbol, chain_id) do
    if symbol == "WETH" && Enum.member?([@mainnet, @optimism], chain_id) do
      "Ether"
    else
      symbol
    end
  end

  defp uniswap_filter_logs(logs) do
    logs
    |> Enum.filter(fn log ->
      first_topic = String.downcase(log.first_topic)

      Enum.member?(
        [
          "0x7a53080ba414158be7ec69b987b5fb7d07dee101fe85488f0853ae16239d0bde",
          "0x0c396cd989a39f4459b5fa1aed6a9a8dcdbc45908acfd67e028cd568da98982c",
          "0x70935338e69775456a85ddef226c395fb668b63fa0115f5f20610b388e6ca9c0",
          "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67"
        ],
        first_topic
      ) ||
        (first_topic == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" &&
           String.downcase(log.address_hash) == @uniswap_v3_positions_nft)
    end)
  end

  defp uniswap_legitimate_pools(logs_grouped) do
    requests =
      logs_grouped
      |> Enum.reduce(%{}, fn {_tx_hash, tx_logs}, addresses_acc ->
        Enum.reduce(tx_logs, addresses_acc, fn log, acc ->
          first_topic = String.downcase(log.first_topic)

          if first_topic != "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" do
            pool_address = String.downcase(log.address_hash)

            Map.put_new(acc, pool_address, true)
          else
            acc
          end
        end)
      end)
      |> Enum.map(fn {pool_address, _} ->
        Enum.map(["0dfe1681", "d21220a7", "ddca3f43"], fn method_id ->
          %{
            contract_address: pool_address,
            method_id: method_id,
            args: []
          }
        end)
      end)
      |> List.flatten()

    max_retries = Application.get_env(:explorer, :token_functions_reader_max_retries)
    responses = read_contracts_with_retries(requests, @uniswap_v3_pool_abi, max_retries)

    if Enum.count(requests) != Enum.count(responses) do
      Logger.error(fn -> "Cannot read Uniswap V3 Pool contract(s)" end)
      %{}
    else
      requests =
        Enum.zip(requests, responses)
        |> Enum.reduce(%{}, fn {request, {_status, response} = _resp}, acc ->
          response =
            case response do
              [item] -> item
              items -> items
            end

          acc = Map.put_new(acc, request.contract_address, %{token0: "", token1: "", fee: ""})
          item = Map.put(acc[request.contract_address], atomized_key(request.method_id), response)
          Map.put(acc, request.contract_address, item)
        end)
        |> Enum.map(fn {pool_address, pool} ->
          token0 = if not is_address_correct?(pool.token0), do: @null_address, else: String.downcase(pool.token0)
          token1 = if not is_address_correct?(pool.token1), do: @null_address, else: String.downcase(pool.token1)
          fee = if pool.fee == "", do: 0, else: pool.fee
          %{
            pool_address: pool_address,
            contract_address: @uniswap_v3_factory,
            method_id: "1698ee82",
            args: [token0, token1, fee]
          }
        end)

      responses = read_contracts_with_retries(requests, @uniswap_v3_factory_abi, max_retries)

      if Enum.count(requests) != Enum.count(responses) do
        Logger.error(fn -> "Cannot read Uniswap V3 Factory contract" end)
        %{}
      else
        Enum.zip(requests, responses)
        |> Enum.reduce(%{}, fn {request, {_status, response} = _resp}, acc ->
          response =
            case response do
              [item] -> item
              items -> items
            end

          Map.put(acc, request.pool_address,
            if request.pool_address == String.downcase(response) do
              [token0, token1, _] = request.args
              [token0, token1]
            else
              []
            end
          )
        end)
      end
    end
  end

  defp atomized_key("token0"), do: :token0
  defp atomized_key("token1"), do: :token1
  defp atomized_key("fee"), do: :fee
  defp atomized_key("getPool"), do: :getPool
  defp atomized_key("symbol"), do: :symbol
  defp atomized_key("decimals"), do: :decimals
  defp atomized_key("0dfe1681"), do: :token0
  defp atomized_key("d21220a7"), do: :token1
  defp atomized_key("ddca3f43"), do: :fee
  defp atomized_key("1698ee82"), do: :getPool
  defp atomized_key("95d89b41"), do: :symbol
  defp atomized_key("313ce567"), do: :decimals

  defp clear_actions(logs_grouped) do
    logs_grouped
    |> Enum.each(fn {tx_hash, _} ->
      from(ta in TransactionActions, where: ta.hash == ^tx_hash) |> Repo.delete_all()
    end)
  end

  defp decode_data("0x", types) do
    for _ <- types, do: nil
  end

  defp decode_data("0x" <> encoded_data, types) do
    encoded_data
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end

  defp get_token_data_from_cache(address) do
    with [{_, value}] <- :ets.lookup(:tokens_data_cache, address) do
      value
    else
      _ -> %{symbol: nil, decimals: nil}
    end
  end

  defp is_address_correct?(address) do
    String.match?(address, ~r/^0x[[:xdigit:]]{40}$/i)
  end

  defp logs_group_by_txs(logs) do
    logs
    |> Enum.reduce(%{}, fn log, acc ->
      acc =
        if not Map.has_key?(acc, log.transaction_hash) do
          Map.put(acc, log.transaction_hash, [])
        else
          acc
        end

      Map.put(acc, log.transaction_hash, acc[log.transaction_hash] ++ [log])
    end)
  end

  defp read_contracts_with_retries(_requests, _abi, 0), do: []

  defp read_contracts_with_retries(requests, abi, retries_left) when retries_left > 0 do
    responses = Reader.query_contracts(requests, abi)
    if Enum.any?(responses, fn {status, _} -> status == :error end) do
      read_contracts_with_retries(requests, abi, retries_left - 1)
    else
      responses
    end
  end

  defp truncate_address_hash(nil), do: "0x0000000000000000000000000000000000000000"

  defp truncate_address_hash("0x000000000000000000000000" <> truncated_hash) do
    "0x#{truncated_hash}"
  end
end
