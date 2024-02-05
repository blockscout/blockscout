defmodule Indexer.Fetcher.Zkevm.Bridge do
  @moduledoc """
  Contains common functions for Indexer.Fetcher.Zkevm.Bridge* modules.
  """

  require Logger

  import EthereumJSONRPC,
    only: [
      integer_to_quantity: 1,
      json_rpc: 2,
      quantity_to_integer: 1,
      request: 1
    ]

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  import Explorer.Helper, only: [decode_data: 2]

  alias EthereumJSONRPC.Logs
  alias Explorer.Chain
  alias Explorer.Chain.Zkevm.Reader
  alias Explorer.SmartContract.Reader, as: SmartContractReader
  alias Indexer.Helper
  alias Indexer.Transform.Addresses

  # 32-byte signature of the event BridgeEvent(uint8 leafType, uint32 originNetwork, address originAddress, uint32 destinationNetwork, address destinationAddress, uint256 amount, bytes metadata, uint32 depositCount)
  @bridge_event "0x501781209a1f8899323b96b4ef08b168df93e0a90c673d1e4cce39366cb62f9b"
  @bridge_event_params [{:uint, 8}, {:uint, 32}, :address, {:uint, 32}, :address, {:uint, 256}, :bytes, {:uint, 32}]

  # 32-byte signature of the event ClaimEvent(uint32 index, uint32 originNetwork, address originAddress, address destinationAddress, uint256 amount)
  @claim_event "0x25308c93ceeed162da955b3f7ce3e3f93606579e40fb92029faa9efe27545983"
  @claim_event_params [{:uint, 32}, {:uint, 32}, :address, :address, {:uint, 256}]

  @symbol_method_selector "95d89b41"
  @decimals_method_selector "313ce567"

  @erc20_abi [
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "symbol",
      "outputs" => [%{"name" => "", "type" => "string"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "decimals",
      "outputs" => [%{"name" => "", "type" => "uint8"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @doc """
  Filters the given list of events keeping only `BridgeEvent` and `ClaimEvent` ones
  emitted by the bridge contract.
  """
  @spec filter_bridge_events(list(), binary()) :: list()
  def filter_bridge_events(events, bridge_contract) do
    Enum.filter(events, fn event ->
      Helper.address_hash_to_string(event.address_hash, true) == bridge_contract and
        Enum.member?([@bridge_event, @claim_event], Helper.log_topic_to_string(event.first_topic))
    end)
  end

  @doc """
  Fetches `BridgeEvent` and `ClaimEvent` events of the bridge contract from an RPC node
  for the given range of blocks.
  """
  @spec get_logs_all({non_neg_integer(), non_neg_integer()}, binary(), list()) :: list()
  def get_logs_all({chunk_start, chunk_end}, bridge_contract, json_rpc_named_arguments) do
    {:ok, result} =
      get_logs(
        chunk_start,
        chunk_end,
        bridge_contract,
        [[@bridge_event, @claim_event]],
        json_rpc_named_arguments
      )

    Logs.elixir_to_params(result)
  end

  defp get_logs(from_block, to_block, address, topics, json_rpc_named_arguments, retries \\ 100_000_000) do
    processed_from_block = if is_integer(from_block), do: integer_to_quantity(from_block), else: from_block
    processed_to_block = if is_integer(to_block), do: integer_to_quantity(to_block), else: to_block

    req =
      request(%{
        id: 0,
        method: "eth_getLogs",
        params: [
          %{
            :fromBlock => processed_from_block,
            :toBlock => processed_to_block,
            :address => address,
            :topics => topics
          }
        ]
      })

    error_message = &"Cannot fetch logs for the block range #{from_block}..#{to_block}. Error: #{inspect(&1)}"

    Helper.repeated_call(&json_rpc/2, [req, json_rpc_named_arguments], error_message, retries)
  end

  @doc """
  Imports the given zkEVM bridge operations into database.
  Used by Indexer.Fetcher.Zkevm.BridgeL1 and Indexer.Fetcher.Zkevm.BridgeL2 fetchers.
  Doesn't return anything.
  """
  @spec import_operations(list()) :: no_return()
  def import_operations(operations) do
    addresses =
      Addresses.extract_addresses(%{
        zkevm_bridge_operations: operations
      })

    {:ok, _} =
      Chain.import(%{
        addresses: %{params: addresses, on_conflict: :nothing},
        zkevm_bridge_operations: %{params: operations},
        timeout: :infinity
      })
  end

  @doc """
  Converts the list of zkEVM bridge events to the list of operations
  preparing them for importing to the database.
  """
  @spec prepare_operations(list(), list() | nil, list(), map() | nil) :: list()
  def prepare_operations(events, json_rpc_named_arguments, json_rpc_named_arguments_l1, block_to_timestamp \\ nil) do
    {block_to_timestamp, token_address_to_id} =
      if is_nil(block_to_timestamp) do
        bridge_events = Enum.filter(events, fn event -> event.first_topic == @bridge_event end)

        l1_token_addresses =
          bridge_events
          |> Enum.reduce(%MapSet{}, fn event, acc ->
            case bridge_event_parse(event) do
              {{nil, _}, _, _} -> acc
              {{token_address, nil}, _, _} -> MapSet.put(acc, token_address)
            end
          end)
          |> MapSet.to_list()

        {
          blocks_to_timestamps(bridge_events, json_rpc_named_arguments),
          token_addresses_to_ids(l1_token_addresses, json_rpc_named_arguments_l1)
        }
      else
        # this is called in realtime
        {block_to_timestamp, %{}}
      end

    Enum.map(events, fn event ->
      {index, l1_token_id, l1_token_address, l2_token_address, amount, block_number, block_timestamp} =
        if event.first_topic == @bridge_event do
          {
            {l1_token_address, l2_token_address},
            amount,
            deposit_count
          } = bridge_event_parse(event)

          l1_token_id = Map.get(token_address_to_id, l1_token_address)
          block_number = quantity_to_integer(event.block_number)
          block_timestamp = Map.get(block_to_timestamp, block_number)

          # credo:disable-for-lines:2 Credo.Check.Refactor.Nesting
          l1_token_address =
            if is_nil(l1_token_id) do
              l1_token_address
            end

          {deposit_count, l1_token_id, l1_token_address, l2_token_address, amount, block_number, block_timestamp}
        else
          [index, _origin_network, _origin_address, _destination_address, amount] =
            decode_data(event.data, @claim_event_params)

          {index, nil, nil, nil, amount, nil, nil}
        end

      is_l1 = json_rpc_named_arguments == json_rpc_named_arguments_l1

      result = %{
        type: operation_type(event.first_topic, is_l1),
        index: index,
        amount: amount
      }

      transaction_hash_field =
        if is_l1 do
          :l1_transaction_hash
        else
          :l2_transaction_hash
        end

      result
      |> extend_result(transaction_hash_field, event.transaction_hash)
      |> extend_result(:l1_token_id, l1_token_id)
      |> extend_result(:l1_token_address, l1_token_address)
      |> extend_result(:l2_token_address, l2_token_address)
      |> extend_result(:block_number, block_number)
      |> extend_result(:block_timestamp, block_timestamp)
    end)
  end

  defp blocks_to_timestamps(events, json_rpc_named_arguments) do
    events
    |> Helper.get_blocks_by_events(json_rpc_named_arguments, 100_000_000)
    |> Enum.reduce(%{}, fn block, acc ->
      block_number = quantity_to_integer(Map.get(block, "number"))
      {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
      Map.put(acc, block_number, timestamp)
    end)
  end

  defp bridge_event_parse(event) do
    [
      leaf_type,
      origin_network,
      origin_address,
      _destination_network,
      _destination_address,
      amount,
      _metadata,
      deposit_count
    ] = decode_data(event.data, @bridge_event_params)

    {token_address_by_origin_address(origin_address, origin_network, leaf_type), amount, deposit_count}
  end

  defp operation_type(first_topic, is_l1) do
    if first_topic == @bridge_event do
      if is_l1, do: :deposit, else: :withdrawal
    else
      if is_l1, do: :withdrawal, else: :deposit
    end
  end

  @doc """
  Fetches L1 token data for the given token addresses,
  builds `L1 token address -> L1 token id` map for them,
  and writes the data to the database. Returns the resulting map.
  """
  @spec token_addresses_to_ids(list(), list()) :: map()
  def token_addresses_to_ids(l1_token_addresses, json_rpc_named_arguments) do
    token_data =
      l1_token_addresses
      |> get_token_data(json_rpc_named_arguments)

    tokens_existing =
      token_data
      |> Map.keys()
      |> Reader.token_addresses_to_ids_from_db()

    tokens_to_insert =
      token_data
      |> Enum.reject(fn {address, _} -> Map.has_key?(tokens_existing, address) end)
      |> Enum.map(fn {address, data} -> Map.put(data, :address, address) end)

    {:ok, inserts} =
      Chain.import(%{
        zkevm_bridge_l1_tokens: %{params: tokens_to_insert},
        timeout: :infinity
      })

    tokens_inserted = Map.get(inserts, :insert_zkevm_bridge_l1_tokens, [])

    # we need to query not inserted tokens from DB separately as they
    # could be inserted by another module at the same time (a race condition).
    # this is an unlikely case but we handle it here as well
    tokens_not_inserted =
      tokens_to_insert
      |> Enum.reject(fn token ->
        Enum.any?(tokens_inserted, fn inserted -> token.address == Helper.address_hash_to_string(inserted.address) end)
      end)
      |> Enum.map(& &1.address)

    tokens_inserted_outside = Reader.token_addresses_to_ids_from_db(tokens_not_inserted)

    tokens_inserted
    |> Enum.reduce(%{}, fn t, acc -> Map.put(acc, Helper.address_hash_to_string(t.address), t.id) end)
    |> Map.merge(tokens_existing)
    |> Map.merge(tokens_inserted_outside)
  end

  defp token_address_by_origin_address(origin_address, origin_network, leaf_type) do
    with true <- leaf_type != 1 and origin_network <= 1,
         token_address = "0x" <> Base.encode16(origin_address, case: :lower),
         true <- token_address != burn_address_hash_string() do
      if origin_network == 0 do
        # this is L1 address
        {token_address, nil}
      else
        # this is L2 address
        {nil, token_address}
      end
    else
      _ -> {nil, nil}
    end
  end

  defp get_token_data(token_addresses, json_rpc_named_arguments) do
    # first, we're trying to read token data from the DB.
    # if tokens are not in the DB, read them through RPC.
    token_addresses
    |> Reader.get_token_data_from_db()
    |> get_token_data_from_rpc(json_rpc_named_arguments)
  end

  defp get_token_data_from_rpc({token_data, token_addresses}, json_rpc_named_arguments) do
    {requests, responses} = get_token_data_request_symbol_decimals(token_addresses, json_rpc_named_arguments)

    requests
    |> Enum.zip(responses)
    |> Enum.reduce(token_data, fn {request, {status, response} = _resp}, token_data_acc ->
      if status == :ok do
        response = parse_response(response)

        address = Helper.address_hash_to_string(request.contract_address, true)

        new_data = get_new_data(token_data_acc[address] || %{}, request, response)

        Map.put(token_data_acc, address, new_data)
      else
        token_data_acc
      end
    end)
  end

  defp get_token_data_request_symbol_decimals(token_addresses, json_rpc_named_arguments) do
    requests =
      token_addresses
      |> Enum.map(fn address ->
        # we will call symbol() and decimals() public getters
        Enum.map([@symbol_method_selector, @decimals_method_selector], fn method_id ->
          %{
            contract_address: address,
            method_id: method_id,
            args: []
          }
        end)
      end)
      |> List.flatten()

    {responses, error_messages} = read_contracts_with_retries(requests, @erc20_abi, json_rpc_named_arguments, 3)

    if !Enum.empty?(error_messages) or Enum.count(requests) != Enum.count(responses) do
      Logger.warning(
        "Cannot read symbol and decimals of an ERC-20 token contract. Error messages: #{Enum.join(error_messages, ", ")}. Addresses: #{Enum.join(token_addresses, ", ")}"
      )
    end

    {requests, responses}
  end

  defp read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left) when retries_left > 0 do
    responses = SmartContractReader.query_contracts(requests, abi, json_rpc_named_arguments: json_rpc_named_arguments)

    error_messages =
      Enum.reduce(responses, [], fn {status, error_message}, acc ->
        acc ++
          if status == :error do
            [error_message]
          else
            []
          end
      end)

    if Enum.empty?(error_messages) do
      {responses, []}
    else
      retries_left = retries_left - 1

      if retries_left == 0 do
        {responses, Enum.uniq(error_messages)}
      else
        :timer.sleep(1000)
        read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left)
      end
    end
  end

  defp get_new_data(data, request, response) do
    if atomized_key(request.method_id) == :symbol do
      Map.put(data, :symbol, response)
    else
      Map.put(data, :decimals, response)
    end
  end

  defp extend_result(result, _key, value) when is_nil(value), do: result
  defp extend_result(result, key, value) when is_atom(key), do: Map.put(result, key, value)

  defp atomized_key("symbol"), do: :symbol
  defp atomized_key("decimals"), do: :decimals
  defp atomized_key(@symbol_method_selector), do: :symbol
  defp atomized_key(@decimals_method_selector), do: :decimals

  defp parse_response(response) do
    case response do
      [item] -> item
      items -> items
    end
  end
end
