defmodule Indexer.Transform.TransactionActions do
  @moduledoc """
  Helper functions for transforming data for transaction actions.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias ABI.TypeDecoder
  alias Explorer.Chain.Cache.NetVersion
  alias Explorer.Chain.TransactionActions
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
  @uniswap_v3_pool_functions %{
    "0dfe1681" => [],
    "d21220a7" => [],
    "ddca3f43" => []
  }

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

      new_actions_acc =
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
      Enum.reduce(tx_logs, %{}, fn log, acc ->
        first_topic = String.downcase(log.first_topic)

        if first_topic != "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" do
          # check UniswapV3Pool contract is legitimate
          pool_address = String.downcase(log.address_hash)

          if legitimate[pool_address] do
            # todo
          end
        end
      end)

      new_actions_acc
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

            if not Map.has_key?(acc, pool_address) do
              Map.put(acc, pool_address, true)
            else
              acc
            end
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
        |> Enum.reduce(%{}, fn {request, {_status, response} = resp}, acc ->
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
          token0 = if not is_address_correct?(pool.token0), do: @null_address, else: pool.token0
          token1 = if not is_address_correct?(pool.token1), do: @null_address, else: pool.token1
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
        |> Enum.reduce(%{}, fn {request, {_status, response} = resp}, acc ->
          is_ok =
            if Map.has_key?(acc, request.pool_address) do
              acc[request.pool_address]
            else
              response =
                case response do
                  [item] -> item
                  items -> items
                end

              request.pool_address == String.downcase(response)
            end

          Map.put(acc, request.pool_address, is_ok)
        end)
      end
    end
  end

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

  # defp encode_address_hash(binary) do
  #   "0x" <> Base.encode16(binary, case: :lower)
  # end

  defp atomized_key("token0"), do: :token0
  defp atomized_key("token1"), do: :token1
  defp atomized_key("fee"), do: :fee
  defp atomized_key("getPool"), do: :getPool
  defp atomized_key("0dfe1681"), do: :token0
  defp atomized_key("d21220a7"), do: :token1
  defp atomized_key("ddca3f43"), do: :fee
  defp atomized_key("1698ee82"), do: :getPool

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
