defmodule Indexer.Fetcher.PolygonZkevm.Bridge do
  @moduledoc """
  Contains common functions for Indexer.Fetcher.PolygonZkevm.Bridge* modules.
  """

  require Logger

  import EthereumJSONRPC,
    only: [
      quantity_to_integer: 1,
      timestamp_to_datetime: 1
    ]

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  import Explorer.Helper, only: [decode_data: 2]

  alias EthereumJSONRPC.Logs
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Explorer.Chain.PolygonZkevm.Reader
  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Transform.Addresses

  # 32-byte signature of the event BridgeEvent(uint8 leafType, uint32 originNetwork, address originAddress, uint32 destinationNetwork, address destinationAddress, uint256 amount, bytes metadata, uint32 depositCount)
  @bridge_event "0x501781209a1f8899323b96b4ef08b168df93e0a90c673d1e4cce39366cb62f9b"
  @bridge_event_params [{:uint, 8}, {:uint, 32}, :address, {:uint, 32}, :address, {:uint, 256}, :bytes, {:uint, 32}]

  # 32-byte signature of the event ClaimEvent(uint32 index, uint32 originNetwork, address originAddress, address destinationAddress, uint256 amount)
  @claim_event_v1 "0x25308c93ceeed162da955b3f7ce3e3f93606579e40fb92029faa9efe27545983"
  @claim_event_v1_params [{:uint, 32}, {:uint, 32}, :address, :address, {:uint, 256}]

  # 32-byte signature of the event ClaimEvent(uint256 globalIndex, uint32 originNetwork, address originAddress, address destinationAddress, uint256 amount)
  @claim_event_v2 "0x1df3f2a973a00d6635911755c260704e95e8a5876997546798770f76396fda4d"
  @claim_event_v2_params [{:uint, 256}, {:uint, 32}, :address, :address, {:uint, 256}]

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
      IndexerHelper.address_hash_to_string(event.address_hash, true) == bridge_contract and
        Enum.member?(
          [@bridge_event, @claim_event_v1, @claim_event_v2],
          IndexerHelper.log_topic_to_string(event.first_topic)
        )
    end)
  end

  @doc """
  Fetches `BridgeEvent` and `ClaimEvent` events of the bridge contract from an RPC node
  for the given range of blocks.
  """
  @spec get_logs_all({non_neg_integer(), non_neg_integer()}, binary(), list()) :: list()
  def get_logs_all({chunk_start, chunk_end}, bridge_contract, json_rpc_named_arguments) do
    {:ok, result} =
      IndexerHelper.get_logs(
        chunk_start,
        chunk_end,
        bridge_contract,
        [[@bridge_event, @claim_event_v1, @claim_event_v2]],
        json_rpc_named_arguments,
        0,
        IndexerHelper.infinite_retries_number()
      )

    Logs.elixir_to_params(result)
  end

  @doc """
  Imports the given zkEVM bridge operations into database.
  Used by Indexer.Fetcher.PolygonZkevm.BridgeL1 and Indexer.Fetcher.PolygonZkevm.BridgeL2 fetchers.
  Doesn't return anything.
  """
  @spec import_operations(list()) :: no_return()
  def import_operations(operations) do
    addresses =
      Addresses.extract_addresses(%{
        polygon_zkevm_bridge_operations: operations
      })

    {:ok, _} =
      Chain.import(%{
        addresses: %{params: addresses, on_conflict: :nothing},
        polygon_zkevm_bridge_operations: %{params: operations},
        timeout: :infinity
      })
  end

  @doc """
  Converts the list of zkEVM bridge events to the list of operations
  preparing them for importing to the database.
  """
  @spec prepare_operations(
          list(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer() | nil,
          non_neg_integer(),
          list() | nil,
          list(),
          map() | nil
        ) ::
          list()
  def prepare_operations(
        events,
        rollup_network_id_l1,
        rollup_network_id_l2,
        rollup_index_l1,
        rollup_index_l2,
        json_rpc_named_arguments,
        json_rpc_named_arguments_l1,
        block_to_timestamp \\ nil
      ) do
    is_l1 = json_rpc_named_arguments == json_rpc_named_arguments_l1

    events = filter_events(events, is_l1, rollup_network_id_l1, rollup_network_id_l2, rollup_index_l1, rollup_index_l2)

    {block_to_timestamp, token_address_to_id} =
      if is_nil(block_to_timestamp) do
        # this function is called by the catchup indexer,
        # so here we can use RPC calls as it's not so critical for delays as in realtime
        bridge_events = Enum.filter(events, fn event -> event.first_topic == @bridge_event end)
        l1_token_addresses = l1_token_addresses_from_bridge_events(bridge_events, rollup_network_id_l2)

        {
          blocks_to_timestamps(bridge_events, json_rpc_named_arguments),
          token_addresses_to_ids(l1_token_addresses, json_rpc_named_arguments_l1)
        }
      else
        # this function is called in realtime by the transformer,
        # so we don't use RPC calls to avoid delays and fetch token data
        # in a separate fetcher
        {block_to_timestamp, %{}}
      end

    events
    |> Enum.map(fn event ->
      {index, l1_token_id, l1_token_address, l2_token_address, amount, block_number, block_timestamp} =
        case event.first_topic do
          @bridge_event ->
            {
              {l1_token_address, l2_token_address},
              amount,
              deposit_count,
              _destination_network
            } = bridge_event_parse(event, rollup_network_id_l2)

            l1_token_id = Map.get(token_address_to_id, l1_token_address)
            block_number = quantity_to_integer(event.block_number)
            block_timestamp = Map.get(block_to_timestamp, block_number)

            # credo:disable-for-lines:2 Credo.Check.Refactor.Nesting
            l1_token_address =
              if is_nil(l1_token_id) do
                l1_token_address
              end

            {deposit_count, l1_token_id, l1_token_address, l2_token_address, amount, block_number, block_timestamp}

          @claim_event_v1 ->
            {index, amount} = claim_event_v1_parse(event)
            {index, nil, nil, nil, amount, nil, nil}

          @claim_event_v2 ->
            {_mainnet_bit, _rollup_idx, index, _origin_network, amount} = claim_event_v2_parse(event)
            {index, nil, nil, nil, amount, nil, nil}
        end

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
    |> IndexerHelper.get_blocks_by_events(json_rpc_named_arguments, IndexerHelper.infinite_retries_number())
    |> Enum.reduce(%{}, fn block, acc ->
      block_number = quantity_to_integer(Map.get(block, "number"))
      timestamp = timestamp_to_datetime(Map.get(block, "timestamp"))
      Map.put(acc, block_number, timestamp)
    end)
  end

  defp bridge_event_parse(event, rollup_network_id_l2) do
    [
      leaf_type,
      origin_network,
      origin_address_bytes,
      destination_network,
      _destination_address,
      amount,
      _metadata,
      deposit_count
    ] = decode_data(event.data, @bridge_event_params)

    {:ok, origin_address_hash} = Hash.Address.cast(origin_address_bytes)

    {token_address_by_origin_address(origin_address_hash, origin_network, leaf_type, rollup_network_id_l2), amount,
     deposit_count, destination_network}
  end

  defp claim_event_v1_parse(event) do
    [index, _origin_network, _origin_address, _destination_address, amount] =
      decode_data(event.data, @claim_event_v1_params)

    {index, amount}
  end

  defp claim_event_v2_parse(event) do
    [global_index, origin_network, _origin_address, _destination_address, amount] =
      decode_data(event.data, @claim_event_v2_params)

    mainnet_bit = Bitwise.band(Bitwise.bsr(global_index, 64), 1)

    bitmask_4bytes = 0xFFFFFFFF

    rollup_index = Bitwise.band(Bitwise.bsr(global_index, 32), bitmask_4bytes)

    index = Bitwise.band(global_index, bitmask_4bytes)

    {mainnet_bit, rollup_index, index, origin_network, amount}
  end

  defp filter_events(events, is_l1, rollup_network_id_l1, rollup_network_id_l2, rollup_index_l1, rollup_index_l2) do
    Enum.filter(events, fn event ->
      case {event.first_topic, is_l1} do
        {@bridge_event, true} -> filter_bridge_event_l1(event, rollup_network_id_l2)
        {@bridge_event, false} -> filter_bridge_event_l2(event, rollup_network_id_l1, rollup_network_id_l2)
        {@claim_event_v2, true} -> filter_claim_event_l1(event, rollup_index_l2)
        {@claim_event_v2, false} -> filter_claim_event_l2(event, rollup_network_id_l1, rollup_index_l1)
        _ -> true
      end
    end)
  end

  defp filter_bridge_event_l1(event, rollup_network_id_l2) do
    {_, _, _, destination_network} = bridge_event_parse(event, rollup_network_id_l2)
    # skip the Deposit event if it's for another rollup
    destination_network == rollup_network_id_l2
  end

  defp filter_bridge_event_l2(event, rollup_network_id_l1, rollup_network_id_l2) do
    {_, _, _, destination_network} = bridge_event_parse(event, rollup_network_id_l2)
    # skip the Withdrawal event if it's for another L1 chain
    destination_network == rollup_network_id_l1
  end

  defp filter_claim_event_l1(event, rollup_index_l2) do
    {mainnet_bit, rollup_idx, _index, _origin_network, _amount} = claim_event_v2_parse(event)

    if mainnet_bit != 0 do
      Logger.error(
        "L1 ClaimEvent has non-zero mainnet bit in the transaction #{event.transaction_hash}. This event will be ignored."
      )
    end

    # skip the Withdrawal event if it's for another rollup or the source network is Ethereum Mainnet
    rollup_idx == rollup_index_l2 and mainnet_bit == 0
  end

  defp filter_claim_event_l2(event, rollup_network_id_l1, rollup_index_l1) do
    {mainnet_bit, rollup_idx, _index, origin_network, _amount} = claim_event_v2_parse(event)

    # skip the Deposit event if it's from another L1 chain
    (mainnet_bit == 1 and rollup_network_id_l1 == 0) or
      (mainnet_bit == 0 and (rollup_idx == rollup_index_l1 or origin_network == rollup_network_id_l1))
  end

  defp l1_token_addresses_from_bridge_events(events, rollup_network_id_l2) do
    events
    |> Enum.reduce(%MapSet{}, fn event, acc ->
      case bridge_event_parse(event, rollup_network_id_l2) do
        {{nil, _}, _, _, _} -> acc
        {{token_address, nil}, _, _, _} -> MapSet.put(acc, token_address)
      end
    end)
    |> MapSet.to_list()
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
        polygon_zkevm_bridge_l1_tokens: %{params: tokens_to_insert},
        timeout: :infinity
      })

    tokens_inserted = Map.get(inserts, :insert_polygon_zkevm_bridge_l1_tokens, [])

    # we need to query not inserted tokens from DB separately as they
    # could be inserted by another module at the same time (a race condition).
    # this is an unlikely case but we handle it here as well
    tokens_not_inserted =
      tokens_to_insert
      |> Enum.reject(fn token ->
        Enum.any?(tokens_inserted, fn inserted ->
          token.address == IndexerHelper.address_hash_to_string(inserted.address)
        end)
      end)
      |> Enum.map(& &1.address)

    tokens_inserted_outside = Reader.token_addresses_to_ids_from_db(tokens_not_inserted)

    tokens_inserted
    |> Enum.reduce(%{}, fn t, acc -> Map.put(acc, IndexerHelper.address_hash_to_string(t.address), t.id) end)
    |> Map.merge(tokens_existing)
    |> Map.merge(tokens_inserted_outside)
  end

  defp token_address_by_origin_address(origin_address, origin_network, leaf_type, rollup_network_id_l2) do
    with true <- leaf_type != 1,
         token_address = to_string(origin_address),
         true <- token_address != burn_address_hash_string() do
      if origin_network != rollup_network_id_l2 do
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

        address = IndexerHelper.address_hash_to_string(request.contract_address, true)

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

    {responses, error_messages} =
      IndexerHelper.read_contracts_with_retries(requests, @erc20_abi, json_rpc_named_arguments, 3)

    if not Enum.empty?(error_messages) or Enum.count(requests) != Enum.count(responses) do
      Logger.warning(
        "Cannot read symbol and decimals of an ERC-20 token contract. Error messages: #{Enum.join(error_messages, ", ")}. Addresses: #{Enum.join(token_addresses, ", ")}"
      )
    end

    {requests, responses}
  end

  defp get_new_data(data, request, response) do
    if atomized_key(request.method_id) == :symbol do
      Map.put(data, :symbol, Reader.sanitize_symbol(response))
    else
      Map.put(data, :decimals, Reader.sanitize_decimals(response))
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
