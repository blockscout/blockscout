defmodule Indexer.Fetcher.Zkevm.BridgeL1 do
  @moduledoc """
  Fills zkevm_bridge DB table.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import Ecto.Query

  import EthereumJSONRPC,
    only: [
      integer_to_quantity: 1,
      json_rpc: 2,
      quantity_to_integer: 1,
      request: 1
    ]

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  import Explorer.Helper, only: [parse_integer: 1, decode_data: 2]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Zkevm.{Bridge, BridgeL1Token}
  alias Explorer.{Chain, Repo}
  alias Explorer.SmartContract.Reader
  alias Indexer.{BoundQueue, Helper}

  @block_check_interval_range_size 100
  @eth_get_logs_range_size 1000
  @fetcher_name :zkevm_bridge_l1

  # 32-byte signature of the event BridgeEvent(uint8 leafType, uint32 originNetwork, address originAddress, uint32 destinationNetwork, address destinationAddress, uint256 amount, bytes metadata, uint32 depositCount)
  @bridge_event "0x501781209a1f8899323b96b4ef08b168df93e0a90c673d1e4cce39366cb62f9b"
  @bridge_event_params [{:uint, 8}, {:uint, 32}, :address, {:uint, 32}, :address, {:uint, 256}, :bytes, {:uint, 32}]

  # 32-byte signature of the event ClaimEvent(uint32 index, uint32 originNetwork, address originAddress, address destinationAddress, uint256 amount)
  @claim_event "0x25308c93ceeed162da955b3f7ce3e3f93606579e40fb92029faa9efe27545983"
  @claim_event_params [{:uint, 32}, {:uint, 32}, :address, :address, {:uint, 256}]

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

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{}, {:continue, :ok}}
  end

  @impl GenServer
  def handle_continue(_, state) do
    Logger.metadata(fetcher: @fetcher_name)
    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    Process.send_after(self(), :init_with_delay, 2000)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:init_with_delay, _state) do
    env = Application.get_all_env(:indexer)[__MODULE__]

    with {:start_block_undefined, false} <- {:start_block_undefined, is_nil(env[:start_block])},
         rpc = env[:rpc],
         {:rpc_undefined, false} <- {:rpc_undefined, is_nil(rpc)},
         {:bridge_contract_address_is_valid, true} <- {:bridge_contract_address_is_valid, Helper.address_correct?(env[:bridge_contract])},
         start_block = parse_integer(env[:start_block]),
         false <- is_nil(start_block),
         true <- start_block > 0,
         {last_l1_block_number, last_l1_transaction_hash} = get_last_l1_item(),
         json_rpc_named_arguments = json_rpc_named_arguments(rpc),
         {:ok, block_check_interval, safe_block} <- get_block_check_interval(json_rpc_named_arguments),
         {:start_block_valid, true} <-
           {:start_block_valid,
            (start_block <= last_l1_block_number || last_l1_block_number == 0) && start_block <= safe_block},
         {:ok, last_l1_tx} <- Helper.get_transaction_by_hash(last_l1_transaction_hash, json_rpc_named_arguments),
         {:l1_tx_not_found, false} <- {:l1_tx_not_found, !is_nil(last_l1_transaction_hash) && is_nil(last_l1_tx)} do
      Process.send(self(), :reorg_monitor, [])
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         block_check_interval: block_check_interval,
         bridge_contract: env[:bridge_contract],
         json_rpc_named_arguments: json_rpc_named_arguments,
         reorg_monitor_prev_latest: 0,
         end_block: safe_block,
         start_block: max(start_block, last_l1_block_number)
       }}
    else
      {:start_block_undefined, true} ->
        # the process shouldn't start if the start block is not defined
        {:stop, :normal, %{}}

      {:rpc_undefined, true} ->
        Logger.error("L1 RPC URL is not defined.")
        {:stop, :normal, %{}}

      {:bridge_contract_address_is_valid, false} ->
        Logger.error("PolygonZkEVMBridge contract address is invalid or not defined.")
        {:stop, :normal, %{}}

      {:start_block_valid, false} ->
        Logger.error("Invalid L1 Start Block value. Please, check the value and zkevm_bridge table.")
        {:stop, :normal, %{}}

      {:error, error_data} ->
        Logger.error(
          "Cannot get last L1 transaction from RPC by its hash, latest block, or block timestamp by its number due to RPC error: #{inspect(error_data)}"
        )

        {:stop, :normal, %{}}

      {:l1_tx_not_found, true} ->
        Logger.error(
          "Cannot find last L1 transaction from RPC by its hash. Probably, there was a reorg on L1 chain. Please, check zkevm_bridge table."
        )

        {:stop, :normal, %{}}

      _ ->
        Logger.error("L1 Start Block is invalid or zero.")
        {:stop, :normal, %{}}
    end
  end

  @impl GenServer
  def handle_info(
        :reorg_monitor,
        %{
          block_check_interval: block_check_interval,
          json_rpc_named_arguments: json_rpc_named_arguments,
          reorg_monitor_prev_latest: prev_latest
        } = state
      ) do
    {:ok, latest} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    if latest < prev_latest do
      Logger.warning("Reorg detected: previous latest block ##{prev_latest}, current latest block ##{latest}.")
      reorg_block_push(latest)
    end

    Process.send_after(self(), :reorg_monitor, block_check_interval)

    {:noreply, %{state | reorg_monitor_prev_latest: latest}}
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          bridge_contract: bridge_contract,
          block_check_interval: block_check_interval,
          start_block: start_block,
          end_block: end_block,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state
      ) do
    time_before = Timex.now()

    last_written_block =
      start_block..end_block
      |> Enum.chunk_every(@eth_get_logs_range_size)
      |> Enum.reduce_while(start_block - 1, fn current_chunk, _ ->
        chunk_start = List.first(current_chunk)
        chunk_end = List.last(current_chunk)

        if chunk_start <= chunk_end do
          Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block, end_block, nil, "L1")

          operations =
            {chunk_start, chunk_end}
            |> get_logs_all(bridge_contract, json_rpc_named_arguments)
            |> prepare_operations(json_rpc_named_arguments)

          import_operations(operations)

          Helper.log_blocks_chunk_handling(
            chunk_start,
            chunk_end,
            start_block,
            end_block,
            "#{Enum.count(operations)} L1 operation(s)",
            "L1"
          )
        end

        reorg_block = reorg_block_pop()

        if !is_nil(reorg_block) && reorg_block > 0 do
          reorg_handle(reorg_block)
          {:halt, if(reorg_block <= chunk_end, do: reorg_block - 1, else: chunk_end)}
        else
          {:cont, chunk_end}
        end
      end)

    new_start_block = last_written_block + 1
    {:ok, new_end_block} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)

    delay =
      if new_end_block == last_written_block do
        # there is no new block, so wait for some time to let the chain issue the new block
        max(block_check_interval - Timex.diff(Timex.now(), time_before, :milliseconds), 0)
      else
        0
      end

    Process.send_after(self(), :continue, delay)

    {:noreply, %{state | start_block: new_start_block, end_block: new_end_block}}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp atomized_key("symbol"), do: :symbol
  defp atomized_key("decimals"), do: :decimals
  defp atomized_key("95d89b41"), do: :symbol
  defp atomized_key("313ce567"), do: :decimals

  defp blocks_to_timestamps(deposit_events, json_rpc_named_arguments) do
    deposit_events
    |> get_blocks_by_events(json_rpc_named_arguments, 100_000_000)
    |> Enum.reduce(%{}, fn block, acc ->
      block_number = quantity_to_integer(Map.get(block, "number"))
      {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
      Map.put(acc, block_number, timestamp)
    end)
  end

  defp extend_result(result, _key, value) when is_nil(value), do: result
  defp extend_result(result, key, value) when is_atom(key), do: Map.put(result, key, value)

  defp get_block_check_interval(json_rpc_named_arguments) do
    {last_safe_block, _} = get_safe_block(json_rpc_named_arguments)

    first_block = max(last_safe_block - @block_check_interval_range_size, 1)

    with {:ok, first_block_timestamp} <-
           Helper.get_block_timestamp_by_number(first_block, json_rpc_named_arguments, 100_000_000),
         {:ok, last_safe_block_timestamp} <-
           Helper.get_block_timestamp_by_number(last_safe_block, json_rpc_named_arguments, 100_000_000) do
      block_check_interval =
        ceil((last_safe_block_timestamp - first_block_timestamp) / (last_safe_block - first_block) * 1000 / 2)

      Logger.info("Block check interval is calculated as #{block_check_interval} ms.")
      {:ok, block_check_interval, last_safe_block}
    else
      {:error, error} ->
        {:error, "Failed to calculate block check interval due to #{inspect(error)}"}
    end
  end

  defp get_blocks_by_events(events, json_rpc_named_arguments, retries) do
    request =
      events
      |> Enum.reduce(%{}, fn event, acc ->
        Map.put(acc, event["blockNumber"], 0)
      end)
      |> Stream.map(fn {block_number, _} -> %{number: block_number} end)
      |> Stream.with_index()
      |> Enum.into(%{}, fn {params, id} -> {id, params} end)
      |> Blocks.requests(&ByNumber.request(&1, false, false))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case Helper.repeated_call(&json_rpc/2, [request, json_rpc_named_arguments], error_message, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end

  defp get_last_l1_item do
    query =
      from(b in Bridge,
        select: {b.block_number, b.l1_transaction_hash},
        where: b.type == :deposit and not is_nil(b.block_number),
        order_by: [desc: b.index],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||({0, nil})
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

  defp get_logs_all({chunk_start, chunk_end}, bridge_contract, json_rpc_named_arguments) do
    {:ok, result} =
      get_logs(
        chunk_start,
        chunk_end,
        bridge_contract,
        [[@bridge_event, @claim_event]],
        json_rpc_named_arguments
      )

    result
  end

  defp get_safe_block(json_rpc_named_arguments) do
    case Helper.get_block_number_by_tag("safe", json_rpc_named_arguments) do
      {:ok, safe_block} ->
        {safe_block, false}

      {:error, :not_found} ->
        {:ok, latest_block} = Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, 100_000_000)
        {latest_block, true}
    end
  end

  defp get_token_data(token_addresses, json_rpc_named_arguments) do
    # first, we're trying to read token data from the DB.
    # if tokens are not in the DB, read them through RPC.
    token_addresses
    |> get_token_data_from_db()
    |> get_token_data_from_rpc(json_rpc_named_arguments)
  end

  defp get_token_data_from_db(token_addresses) do
    # try to read token symbols and decimals from the database
    query =
      from(
        t in BridgeL1Token,
        where: t.address in ^token_addresses,
        select: {t.address, t.decimals, t.symbol}
      )

    token_data =
      query
      |> Repo.all()
      |> Enum.reduce(%{}, fn {address, decimals, symbol}, acc ->
        token_address = String.downcase(Hash.to_string(address))
        Map.put(acc, token_address, %{symbol: symbol, decimals: decimals})
      end)

    token_addresses_for_rpc =
      token_addresses
      |> Enum.reject(fn address ->
        Map.has_key?(token_data, String.downcase(address))
      end)

    {token_data, token_addresses_for_rpc}
  end

  defp get_token_data_from_rpc({token_data, token_addresses}, json_rpc_named_arguments) do
    {requests, responses} = get_token_data_request_symbol_decimals(token_addresses, json_rpc_named_arguments)

    requests
    |> Enum.zip(responses)
    |> Enum.reduce(token_data, fn {request, {status, response} = _resp}, token_data_acc ->
      if status == :ok do
        response = parse_response(response)

        address = String.downcase(request.contract_address)

        new_data = get_new_data(token_data_acc[address] || %{}, request, response)

        Map.put(token_data_acc, address, new_data)
      else
        token_data_acc
      end
    end)
  end

  defp parse_response(response) do
    case response do
      [item] -> item
      items -> items
    end
  end

  defp get_new_data(data, request, response) do
    if atomized_key(request.method_id) == :symbol do
      Map.put(data, :symbol, response)
    else
      Map.put(data, :decimals, response)
    end
  end

  defp get_token_data_request_symbol_decimals(token_addresses, json_rpc_named_arguments) do
    requests =
      token_addresses
      |> Enum.map(fn address ->
        # we will call symbol() and decimals() public getters
        Enum.map(["95d89b41", "313ce567"], fn method_id ->
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

  defp import_operations(operations) do
    # here we explicitly check CHAIN_TYPE as Dialyzer throws an error otherwise
    import_options =
      if System.get_env("CHAIN_TYPE") == "polygon_zkevm" do
        %{
          zkevm_bridge_operations: %{params: operations},
          timeout: :infinity
        }
      else
        %{}
      end

    {:ok, _} = Chain.import(import_options)
  end

  defp json_rpc_named_arguments(rpc_url) do
    [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: rpc_url,
        http_options: [
          recv_timeout: :timer.minutes(10),
          timeout: :timer.minutes(10),
          hackney: [pool: :ethereum_jsonrpc]
        ]
      ]
    ]
  end

  defp prepare_operations(events, json_rpc_named_arguments) do
    deposit_events = Enum.filter(events, fn event -> Enum.at(event["topics"], 0) == @bridge_event end)

    block_to_timestamp = blocks_to_timestamps(deposit_events, json_rpc_named_arguments)

    token_address_to_id = token_addresses_to_ids(deposit_events, json_rpc_named_arguments)

    Enum.map(events, fn event ->
      {type, index, l1_token_id, l2_token_address, amount, block_number, block_timestamp} =
        if Enum.at(event["topics"], 0) == @bridge_event do
          [
            leaf_type,
            origin_network,
            origin_address,
            _destination_network,
            _destination_address,
            amount,
            _metadata,
            deposit_count
          ] = decode_data(event["data"], @bridge_event_params)

          {l1_token_address, l2_token_address} =
            token_address_by_origin_address(origin_address, origin_network, leaf_type)

          l1_token_id = Map.get(token_address_to_id, l1_token_address)
          block_number = quantity_to_integer(event["blockNumber"])
          block_timestamp = Map.get(block_to_timestamp, block_number)

          {:deposit, deposit_count, l1_token_id, l2_token_address, amount, block_number, block_timestamp}
        else
          [index, _origin_network, _origin_address, _destination_address, amount] =
            decode_data(event["data"], @claim_event_params)

          {:withdrawal, index, nil, nil, amount, nil, nil}
        end

      result = %{
        type: type,
        index: index,
        l1_transaction_hash: event["transactionHash"],
        amount: amount
      }

      result
      |> extend_result(:l1_token_id, l1_token_id)
      |> extend_result(:l2_token_address, l2_token_address)
      |> extend_result(:block_number, block_number)
      |> extend_result(:block_timestamp, block_timestamp)
    end)
  end

  defp read_contracts_with_retries(requests, abi, json_rpc_named_arguments, retries_left) when retries_left > 0 do
    responses = Reader.query_contracts(requests, abi, json_rpc_named_arguments: json_rpc_named_arguments)

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

  defp reorg_block_pop do
    table_name = reorg_table_name(@fetcher_name)

    case BoundQueue.pop_front(reorg_queue_get(table_name)) do
      {:ok, {block_number, updated_queue}} ->
        :ets.insert(table_name, {:queue, updated_queue})
        block_number

      {:error, :empty} ->
        nil
    end
  end

  defp reorg_block_push(block_number) do
    table_name = reorg_table_name(@fetcher_name)
    {:ok, updated_queue} = BoundQueue.push_back(reorg_queue_get(table_name), block_number)
    :ets.insert(table_name, {:queue, updated_queue})
  end

  defp reorg_handle(reorg_block) do
    {deleted_count, _} =
      Repo.delete_all(from(b in Bridge, where: b.type == :deposit and b.l1_block_number >= ^reorg_block))

    if deleted_count > 0 do
      Logger.warning(
        "As L1 reorg was detected, some deposits with block_number >= #{reorg_block} were removed from zkevm_bridge table. Number of removed rows: #{deleted_count}."
      )
    end
  end

  defp reorg_queue_get(table_name) do
    if :ets.whereis(table_name) == :undefined do
      :ets.new(table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    with info when info != :undefined <- :ets.info(table_name),
         [{_, value}] <- :ets.lookup(table_name, :queue) do
      value
    else
      _ -> %BoundQueue{}
    end
  end

  defp reorg_table_name(fetcher_name) do
    :"#{fetcher_name}#{:_reorgs}"
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

  defp token_addresses_to_ids(deposit_events, json_rpc_named_arguments) do
    token_data =
      deposit_events
      |> Enum.reduce(%MapSet{}, fn event, acc ->
        [
          leaf_type,
          origin_network,
          origin_address,
          _destination_network,
          _destination_address,
          _amount,
          _metadata,
          _deposit_count
        ] = decode_data(event["data"], @bridge_event_params)

        case token_address_by_origin_address(origin_address, origin_network, leaf_type) do
          {nil, _} -> acc
          {token_address, nil} -> MapSet.put(acc, token_address)
        end
      end)
      |> MapSet.to_list()
      |> get_token_data(json_rpc_named_arguments)

    tokens_existing =
      token_data
      |> Map.keys()
      |> token_addresses_to_ids_from_db()

    tokens_to_insert =
      token_data
      |> Enum.reject(fn {address, _} -> Map.has_key?(tokens_existing, address) end)
      |> Enum.map(fn {address, data} -> Map.put(data, :address, address) end)

    # here we explicitly check CHAIN_TYPE as Dialyzer throws an error otherwise
    import_options =
      if System.get_env("CHAIN_TYPE") == "polygon_zkevm" do
        %{
          zkevm_bridge_l1_tokens: %{params: tokens_to_insert},
          timeout: :infinity
        }
      else
        %{}
      end

    {:ok, inserts} = Chain.import(import_options)

    tokens_inserted = Map.get(inserts, :insert_zkevm_bridge_l1_tokens, [])

    # we need to query uninserted tokens separately from DB as they
    # could be inserted by BridgeL2 module at the same time (a race condition).
    # this is an unlikely case but we handle it here as well
    tokens_uninserted =
      tokens_to_insert
      |> Enum.reject(fn token ->
        Enum.any?(tokens_inserted, fn inserted -> token.address == Hash.to_string(inserted.address) end)
      end)
      |> Enum.map(& &1.address)

    tokens_inserted_outside = token_addresses_to_ids_from_db(tokens_uninserted)

    tokens_inserted
    |> Enum.reduce(%{}, fn t, acc -> Map.put(acc, Hash.to_string(t.address), t.id) end)
    |> Map.merge(tokens_existing)
    |> Map.merge(tokens_inserted_outside)
  end

  defp token_addresses_to_ids_from_db(addresses) do
    query = from(t in BridgeL1Token, select: {t.address, t.id}, where: t.address in ^addresses)

    query
    |> Repo.all(timeout: :infinity)
    |> Enum.reduce(%{}, fn {address, id}, acc -> Map.put(acc, Hash.to_string(address), id) end)
  end
end
