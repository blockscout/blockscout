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
  alias Explorer.Token.MetadataRetriever

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
        |> uniswap(actions)
      else
        actions
      end

    %{transaction_actions: actions}
  end

  defp uniswap(logs_grouped, actions) do
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
        actions_acc ++
          Enum.map(mint_nft_ids, fn {to, ids} ->
            %{
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
            }
          end)

      # go through other actions
      actions_acc =
        actions_acc ++
          Enum.reduce(tx_logs, [], fn log, acc ->
            first_topic = String.downcase(log.first_topic)

            if first_topic == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" do
              acc
            else
              # check UniswapV3Pool contract is legitimate
              pool_address = String.downcase(log.address_hash)

              if Enum.count(legitimate[pool_address]) == 0 do
                # this is not legitimate uniswap pool, so skip this address
                acc
              else
                [token0_address, token1_address] = legitimate[pool_address]

                # try to read token symbols and decimals from cache
                token0_data = get_token_data_from_cache(token0_address)
                token1_data = get_token_data_from_cache(token1_address)

                select_tokens_from_db = []

                select_tokens_from_db =
                  select_tokens_from_db ++
                    if is_nil(token0_data.symbol) or is_nil(token0_data.decimals) do
                      [token0_address]
                    else
                      []
                    end

                select_tokens_from_db =
                  select_tokens_from_db ++
                    if is_nil(token1_data.symbol) or is_nil(token1_data.decimals) do
                      [token1_address]
                    else
                      []
                    end

                {token0_data, token1_data} =
                  if Enum.count(select_tokens_from_db) != 0 do
                    # try to read token symbols and decimals from DB and save to cache
                    query = from(
                      t in Token,
                      where: t.contract_address_hash in ^select_tokens_from_db,
                      select: {t.symbol, t.decimals, t.contract_address_hash}
                    )

                    tokens_data =
                      query
                      |> Repo.all()
                      |> Enum.reduce(%{token0_symbol: token0_data.symbol, token0_decimals: token0_data.decimals, token1_symbol: token1_data.symbol, token1_decimals: token1_data.decimals}, fn {symbol, decimals, contract_address_hash}, query_acc ->
                        if String.downcase(Hash.to_string(contract_address_hash)) == token0_address do
                          symbol =
                            if is_nil(symbol) or symbol == "" do
                              # if db field is empty, take it from the cache
                              query_acc.token0_symbol
                            else
                              symbol
                            end

                          decimals =
                            if is_nil(decimals) do
                              # if db field is empty, take it from the cache
                              query_acc.token0_decimals
                            else
                              decimals
                            end

                          %{query_acc | token0_symbol: symbol, token0_decimals: decimals}
                        else
                          symbol =
                            if is_nil(symbol) or symbol == "" do
                              # if db field is empty, take it from the cache
                              query_acc.token1_symbol
                            else
                              symbol
                            end

                          decimals =
                            if is_nil(decimals) do
                              # if db field is empty, take it from the cache
                              query_acc.token1_decimals
                            else
                              decimals
                            end

                          %{query_acc | token1_symbol: symbol, token1_decimals: decimals}
                        end
                      end)

                    token0_data = %{symbol: tokens_data.token0_symbol, decimals: tokens_data.token0_decimals}
                    token1_data = %{symbol: tokens_data.token1_symbol, decimals: tokens_data.token1_decimals}

                    :ets.insert(:tokens_data_cache, {token0_address, token0_data})
                    :ets.insert(:tokens_data_cache, {token1_address, token1_data})

                    {token0_data, token1_data}
                  else
                    {token0_data, token1_data}
                  end

                read_tokens_from_rpc = []

                read_tokens_from_rpc =
                  read_tokens_from_rpc ++
                    if is_nil(token0_data.symbol) or token0_data.symbol == "" or is_nil(token0_data.decimals) do
                      [token0_address]
                    else
                      []
                    end

                read_tokens_from_rpc =
                  read_tokens_from_rpc ++
                    if is_nil(token1_data.symbol) or token1_data.symbol == "" or is_nil(token1_data.decimals) do
                      [token1_address]
                    else
                      []
                    end

                {token0_data, token1_data} =
                  if Enum.count(read_tokens_from_rpc) != 0 do
                    # try to read token symbols and decimals from RPC and save to cache
                    # todo
                  else
                    {token0_data, token1_data}
                  end

                # todo

                acc
              end
            end
          end)

      actions_acc
    end)
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
  defp atomized_key("0dfe1681"), do: :token0
  defp atomized_key("d21220a7"), do: :token1
  defp atomized_key("ddca3f43"), do: :fee
  defp atomized_key("1698ee82"), do: :getPool

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
