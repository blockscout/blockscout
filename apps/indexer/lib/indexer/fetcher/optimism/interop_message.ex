defmodule Indexer.Fetcher.Optimism.InteropMessage do
  @moduledoc """
    Fills op_interop_messages DB table by catching `SentMessage` and `RelayedMessage` events.

    The table stores indexed interop messages which are got from `SentMessage` and `RelayedMessage` events
    emitted by the `L2ToL2CrossDomainMessenger` predeploy smart contract. The messages are scanned starting from
    the block number defined in INDEXER_OPTIMISM_L2_INTEROP_START_BLOCK env variable. If the variable is not
    defined, the module doesn't start.

    Each message always consists of two transactions: initial transaction on the source chain and relay transaction
    on the target chain. The initial transaction emits the `SentMessage` event, and the relay transaction emits the
    `RelayedMessage` event.

    The message is treated as outgoing when its initial transaction was created on the local chain and the corresponding
    relay transaction was executed on the remote chain. The message is treated as incoming when its initial transaction
    was created on the remote chain and the corresponding relay transaction was executed on the local chain.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [id_to_params: 1, quantity_to_integer: 1, integer_to_quantity: 1]
  import Explorer.Helper, only: [decode_data: 2, truncate_address_hash: 1]

  alias EthereumJSONRPC.Block.ByNumber
  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.Optimism.InteropMessage
  alias Explorer.Chain.RollupReorgMonitorQueue
  alias Indexer.Fetcher.Optimism
  alias Indexer.Helper

  @fetcher_name :optimism_interop_messages
  @l2tol2_cross_domain_messenger "0x4200000000000000000000000000000000000023"
  @blocks_batch_request_max_size 25

  # 32-byte signature of the event SentMessage(uint256 indexed destination, address indexed target, uint256 indexed messageNonce, address sender, bytes message)
  @sent_message_event "0x382409ac69001e11931a28435afef442cbfd20d9891907e8fa373ba7d351f320"

  # 32-byte signature of the event RelayedMessage(uint256 indexed source, uint256 indexed messageNonce, bytes32 indexed messageHash)
  @relayed_message_event "0x5948076590932b9d173029c7df03fe386e755a61c86c7fe2671011a2faa2a379"

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
  def init(args) do
    json_rpc_named_arguments = args[:json_rpc_named_arguments]
    {:ok, %{}, {:continue, json_rpc_named_arguments}}
  end

  # Initialization function which is used instead of `init` to avoid Supervisor's stop in case of any critical issues
  # during initialization. It checks the value of INDEXER_OPTIMISM_L2_INTEROP_START_BLOCK env variable, defines the
  # block range which must be scanned to handle `SentMessage` and `RelayedMessage` events, and starts the handling loop.
  #
  # The block range is split into chunks which max size is defined by INDEXER_OPTIMISM_L2_ETH_GET_LOGS_RANGE_SIZE
  # env variable.
  #
  # Also, the function fetches the current chain id to use it in the handler (to write correct `init_chain_id` and
  # `relay_chain_id` fields).
  #
  # When the initialization succeeds, the `:continue` message is sent to GenServer to start the catchup loop
  # retrieving and saving historical events (and after that, it's switched to realtime mode).
  #
  # ## Parameters
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection to RPC node.
  # - `_state`: Initial state of the fetcher (empty map when starting).
  #
  # ## Returns
  # - `{:noreply, state}` when the initialization is successful and the fetching can start. The `state` contains
  #                       necessary parameters needed for the fetching.
  # - `{:stop, :normal, %{}}` in case of error or when the INDEXER_OPTIMISM_L2_INTEROP_START_BLOCK is not defined.
  @impl GenServer
  @spec handle_continue(EthereumJSONRPC.json_rpc_named_arguments(), map()) ::
          {:noreply, map()} | {:stop, :normal, map()}
  def handle_continue(json_rpc_named_arguments, _state) do
    Logger.metadata(fetcher: @fetcher_name)

    # two seconds pause needed to avoid exceeding Supervisor restart intensity when DB issues
    :timer.sleep(2000)

    env = Application.get_all_env(:indexer)[__MODULE__]
    optimism_env = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism]
    block_number = env[:start_block]

    with false <- is_nil(block_number),
         chain_id = Optimism.fetch_chain_id(),
         {:chain_id_is_nil, false} <- {:chain_id_is_nil, is_nil(chain_id)},
         Subscriber.to(:blocks, :realtime),
         {:ok, latest_block_number} =
           Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number()),
         InteropMessage.remove_invalid_messages(latest_block_number),
         {:ok, last_block_number} <- get_last_block_number(json_rpc_named_arguments, chain_id) do
      Logger.info("last_block_number = #{last_block_number}")
      Logger.info("latest_block_number = #{latest_block_number}")

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         start_block_number: max(block_number, last_block_number),
         end_block_number: latest_block_number,
         chunk_size: optimism_env[:l2_eth_get_logs_range_size],
         mode: :catchup,
         realtime_range: nil,
         last_realtime_block_number: nil,
         json_rpc_named_arguments: json_rpc_named_arguments,
         chain_id: chain_id
       }}
    else
      true ->
        # Start block is not defined, so we don't start this module
        {:stop, :normal, %{}}

      {:chain_id_is_nil, true} ->
        Logger.error("Cannot get chain ID from RPC.")
        {:stop, :normal, %{}}

      {:error, error_data} ->
        Logger.error("Cannot get last transaction from RPC by its hash due to RPC error: #{inspect(error_data)}")
        {:stop, :normal, %{}}
    end
  end

  # Performs the main handling loop for the specified block range. The block range is split into chunks.
  # Max size of a chunk is defined by INDEXER_OPTIMISM_L2_INTEROP_START_BLOCK env variable.
  #
  # If there are reorg blocks in the block range, the reorgs are handled. In a normal situation,
  # the realtime block range is formed by `handle_info({:chain_event, :blocks, :realtime, blocks}, state)`
  # handler.
  #
  # ## Parameters
  # - `:continue`: The GenServer message.
  # - `state`: The current state of the fetcher containing block range, max chunk size, etc.
  #
  # ## Returns
  # - `{:noreply, state}` tuple where `state` is the new state of the fetcher which can have updated block
  #    range and other parameters.
  @impl GenServer
  def handle_info(
        :continue,
        %{
          start_block_number: start_block_number,
          end_block_number: end_block_number,
          chunk_size: chunk_size,
          mode: mode,
          last_realtime_block_number: last_realtime_block_number,
          json_rpc_named_arguments: json_rpc_named_arguments,
          chain_id: chain_id
        } = state
      ) do
    {new_start_block_number, new_end_block_number, reorg_block_number} =
      start_block_number..end_block_number
      |> Enum.chunk_every(chunk_size)
      |> Enum.reduce_while({nil, nil, nil}, fn block_numbers, _acc ->
        chunk_start = List.first(block_numbers)
        chunk_end = List.last(block_numbers)

        Helper.log_blocks_chunk_handling(chunk_start, chunk_end, start_block_number, end_block_number, nil, :L2)

        events_count = handle_events(chunk_start, chunk_end, json_rpc_named_arguments, chain_id)

        Helper.log_blocks_chunk_handling(
          chunk_start,
          chunk_end,
          start_block_number,
          end_block_number,
          "#{events_count} event(s).",
          :L2
        )

        reorg_block_number = handle_reorgs_queue(__MODULE__)

        cond do
          is_nil(reorg_block_number) or reorg_block_number > end_block_number ->
            {:cont, {nil, nil, reorg_block_number}}

          reorg_block_number < start_block_number ->
            new_start_block_number = reorg_block_number
            new_end_block_number = reorg_block_number
            {:halt, {new_start_block_number, new_end_block_number, reorg_block_number}}

          true ->
            new_start_block_number = min(chunk_end + 1, reorg_block_number)
            new_end_block_number = reorg_block_number
            {:halt, {new_start_block_number, new_end_block_number, reorg_block_number}}
        end
      end)

    new_last_realtime_block_number =
      if is_nil(reorg_block_number) do
        last_realtime_block_number
      else
        reorg_block_number
      end

    if is_nil(new_start_block_number) or is_nil(new_end_block_number) do
      # if there wasn't a reorg or the reorg didn't affect the current range, switch to realtime mode
      if mode == :catchup do
        Logger.info("The fetcher catchup loop for the range #{inspect(start_block_number..end_block_number)} finished.")
        Logger.info("Switching to realtime mode...")
      end

      {:noreply, %{state | mode: :realtime, last_realtime_block_number: new_last_realtime_block_number}}
    else
      # if the reorg affected the current range, cut the range (see the code above)
      # so that the last block of the range is the reorg block number, and handle the new range
      Process.send(self(), :continue, [])

      {:noreply,
       %{
         state
         | start_block_number: new_start_block_number,
           end_block_number: new_end_block_number,
           last_realtime_block_number: new_last_realtime_block_number
       }}
    end
  end

  # Catches new block from the realtime block fetcher to form the next block range to handle by the main loop.
  #
  # ## Parameters
  # - `{:chain_event, :blocks, :realtime, blocks}`: The GenServer message containing the list of blocks
  #                                                 taken by the realtime block fetcher.
  # - `state`: The current fetcher state containing the current block range and other parameters for realtime handling.
  #
  # ## Returns
  # - `{:noreply, state}` tuple where `state` is the new state of the fetcher containing the updated block range and other parameters.
  @impl GenServer
  def handle_info({:chain_event, :blocks, :realtime, blocks}, state) do
    handle_realtime_blocks(blocks, state)
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def handle_realtime_blocks([], state) do
    Logger.info("Got an empty list of new realtime block numbers")
    {:noreply, state}
  end

  def handle_realtime_blocks(
        blocks,
        %{realtime_range: realtime_range, mode: mode, last_realtime_block_number: last_realtime_block_number} = state
      ) do
    {new_min, new_max} =
      blocks
      |> Enum.map(fn block -> block.number end)
      |> Enum.min_max()

    if new_min != new_max do
      Logger.info("Got a range of new realtime block numbers: #{inspect(new_min..new_max)}")
    else
      Logger.info("Got a new realtime block number #{new_max}")
    end

    {start_block_number, end_block_number} =
      case realtime_range do
        nil -> {new_min, new_max}
        prev_min..prev_max//_ -> {min(prev_min, new_min), max(prev_max, new_max)}
      end

    start_block_number_updated =
      if last_realtime_block_number < start_block_number do
        last_realtime_block_number + 1
      else
        start_block_number
      end

    new_realtime_range = Range.new(start_block_number_updated, end_block_number)

    if mode == :realtime do
      Logger.info("The current realtime range is #{inspect(new_realtime_range)}. Starting to handle that...")

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         state
         | start_block_number: start_block_number_updated,
           end_block_number: end_block_number,
           mode: :continue,
           realtime_range: nil,
           last_realtime_block_number: new_max
       }}
    else
      {:noreply, %{state | realtime_range: new_realtime_range, last_realtime_block_number: new_max}}
    end
  end

  @doc """
    Catches L2 reorg block from the realtime block fetcher and keeps it in a queue
    to handle that by the main loop.

    ## Parameters
    - `reorg_block_number`: The number of reorg block.

    ## Returns
    - nothing.
  """
  @spec handle_realtime_l2_reorg(non_neg_integer()) :: any()
  def handle_realtime_l2_reorg(reorg_block_number) do
    Logger.warning("L2 reorg was detected at block #{reorg_block_number}.", fetcher: @fetcher_name)
    RollupReorgMonitorQueue.reorg_block_push(reorg_block_number, __MODULE__)
  end

  # Removes all rows from the `op_interop_messages` table which have `block_number` greater or equal to the reorg block number.
  #
  # ## Parameters
  # - `reorg_block_number`: The reorg block number.
  #
  # ## Returns
  # - nothing.
  @spec handle_reorg(non_neg_integer() | nil) :: any()
  defp handle_reorg(reorg_block_number) when not is_nil(reorg_block_number) do
    deleted_count = InteropMessage.remove_invalid_messages(reorg_block_number - 1)

    if deleted_count > 0 do
      Logger.warning(
        "As L2 reorg was detected, all rows with block_number >= #{reorg_block_number} were removed from the `op_interop_messages` table. Number of removed rows: #{deleted_count}."
      )
    end
  end

  defp handle_reorg(_reorg_block_number), do: :ok

  @doc """
    Reads reorg block numbers queue for the specified module and pops the block numbers from that
    finding the earliest one.

    ## Parameters
    - `module`: The module for which the queue should be read.

    ## Returns
    - The earliest reorg block number.
    - `nil` if the queue is empty.
  """
  @spec handle_reorgs_queue(module()) :: non_neg_integer() | nil
  def handle_reorgs_queue(module) do
    reorg_block_number =
      Enum.reduce_while(Stream.iterate(0, &(&1 + 1)), nil, fn _i, acc ->
        number = RollupReorgMonitorQueue.reorg_block_pop(module)

        if is_nil(number) do
          {:halt, acc}
        else
          {:cont, min(number, acc)}
        end
      end)

    handle_reorg(reorg_block_number)

    reorg_block_number
  end

  # Searches events in the given block range and prepares the list of items to import to `op_interop_messages` table.
  #
  # ## Parameters
  # - `start_block_number`: The start block number of the block range for which we need to search and handle the events.
  # - `end_block_number`: The end block number of the block range for which we need to search and handle the events.
  #                       Note that the length of the range cannot be larger than max batch request size on RPC node.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  # - `current_chain_id`: The current chain ID to use it for `init_chain_id` or `relay_chain_id` field.
  #
  # ## Returns
  # - The number of found `SentMessage` and `RelayedMessage` events.
  @spec handle_events(
          non_neg_integer(),
          non_neg_integer(),
          EthereumJSONRPC.json_rpc_named_arguments(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp handle_events(start_block_number, end_block_number, json_rpc_named_arguments, current_chain_id) do
    {:ok, events} =
      Optimism.get_logs(
        start_block_number,
        end_block_number,
        @l2tol2_cross_domain_messenger,
        [@sent_message_event, @relayed_message_event],
        json_rpc_named_arguments,
        Helper.infinite_retries_number()
      )

    timestamps =
      events
      |> Enum.filter(fn event -> Enum.at(event["topics"], 0) == @sent_message_event end)
      |> block_timestamp_by_number(json_rpc_named_arguments)

    messages =
      Enum.map(events, fn event ->
        block_number = quantity_to_integer(event["blockNumber"])

        if Enum.at(event["topics"], 0) == @sent_message_event do
          [sender, payload] = decode_data(event["data"], [:address, :bytes])

          %{
            sender: sender,
            target: truncate_address_hash(Enum.at(event["topics"], 2)),
            nonce: quantity_to_integer(Enum.at(event["topics"], 3)),
            init_chain_id: current_chain_id,
            init_transaction_hash: event["transactionHash"],
            block_number: block_number,
            timestamp: Map.get(timestamps, block_number),
            relay_chain_id: quantity_to_integer(Enum.at(event["topics"], 1)),
            payload: payload
          }
        else
          %{
            nonce: quantity_to_integer(Enum.at(event["topics"], 2)),
            init_chain_id: quantity_to_integer(Enum.at(event["topics"], 1)),
            block_number: block_number,
            relay_chain_id: current_chain_id,
            relay_transaction_hash: event["transactionHash"],
            failed: false
          }
        end
      end)

    {:ok, _} =
      Chain.import(%{
        optimism_interop_messages: %{params: messages},
        timeout: :infinity
      })

    Enum.count(messages)
  end

  @doc """
    Gets the last known block number from the `op_interop_messages` database table.
    When the block number is found, the function checks that for actuality (to avoid reorg cases).
    If the block is not consensus, the corresponding row is removed from the table and
    the previous block becomes under consideration, and so on until a row with non-reorged
    block is found.

    ## Parameters
    - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
    - `current_chain_id`: The current chain ID.
    - `only_failed`: True if only failed relay transactions are taken into account.

    ## Returns
    - `{:ok, number}` tuple with the block number of the last actual row. The number can be `0` if there are no rows.
    - `{:error, message}` tuple in case of RPC error.
  """
  @spec get_last_block_number(EthereumJSONRPC.json_rpc_named_arguments(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, any()}
  def get_last_block_number(json_rpc_named_arguments, current_chain_id, only_failed \\ false) do
    {last_block_number, last_transaction_hash} = InteropMessage.get_last_item(current_chain_id, only_failed)

    with {:empty_hash, false} <- {:empty_hash, is_nil(last_transaction_hash)},
         {:ok, last_transaction} <- Optimism.get_transaction_by_hash(last_transaction_hash, json_rpc_named_arguments),
         {:empty_transaction, false} <- {:empty_transaction, is_nil(last_transaction)} do
      {:ok, last_block_number}
    else
      {:empty_hash, true} ->
        {:ok, 0}

      {:error, _} = error ->
        error

      {:empty_transaction, true} ->
        Logger.error(
          "Cannot find the last transaction from RPC by its hash (#{last_transaction_hash}). Probably, there was a reorg. Trying to check preceding transaction..."
        )

        InteropMessage.remove_invalid_messages(last_block_number - 1)

        get_last_block_number(json_rpc_named_arguments, current_chain_id)
    end
  end

  # Builds a map `block_number -> timestamp` from the given list of events.
  #
  # Firstly, the function tries to find timestamps for blocks in the `blocks` table in database.
  # If the timestamp for block is not found in database, it's read from RPC.
  #
  # ## Parameters
  # - `events`: The list of events for which we need to retrieve block timestamps.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - `block_number -> timestamp` map.
  @spec block_timestamp_by_number(list(), EthereumJSONRPC.json_rpc_named_arguments()) :: map()
  defp block_timestamp_by_number(events, json_rpc_named_arguments) do
    block_numbers =
      events
      |> Enum.reduce(MapSet.new(), fn event, acc ->
        MapSet.put(acc, quantity_to_integer(event["blockNumber"]))
      end)
      |> MapSet.to_list()

    block_timestamp_from_db = Chain.timestamp_by_block_number(block_numbers)

    block_numbers
    |> Enum.reject(&Map.has_key?(block_timestamp_from_db, &1))
    |> Enum.chunk_every(@blocks_batch_request_max_size)
    |> Enum.reduce(block_timestamp_from_db, fn numbers, acc ->
      numbers
      |> get_blocks_by_numbers_from_rpc(json_rpc_named_arguments, Helper.infinite_retries_number())
      |> Enum.reduce(acc, fn block, bn_to_ts_acc ->
        block_number = quantity_to_integer(Map.get(block, "number"))
        {:ok, timestamp} = DateTime.from_unix(quantity_to_integer(Map.get(block, "timestamp")))
        Map.put(bn_to_ts_acc, block_number, timestamp)
      end)
    end)
  end

  # Fetches blocks from RPC by their numbers.
  #
  # ## Parameters
  # - `block_numbers`: The list of block numbers (each number can be integer or in form of `0x` quantity).
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  # - `retries`: Number of retry attempts if the request fails.
  #
  # ## Returns
  # - The list of blocks. The list will be empty if all retries to RPC were failed.
  @spec get_blocks_by_numbers_from_rpc(list(), EthereumJSONRPC.json_rpc_named_arguments(), non_neg_integer()) :: list()
  defp get_blocks_by_numbers_from_rpc(block_numbers, json_rpc_named_arguments, retries) do
    request =
      block_numbers
      |> Stream.map(fn block_number -> %{number: integer_to_quantity(block_number)} end)
      |> id_to_params()
      |> Blocks.requests(&ByNumber.request(&1, false, false))

    error_message = &"Cannot fetch blocks with batch request. Error: #{inspect(&1)}. Request: #{inspect(request)}"

    case Optimism.repeated_request(request, error_message, json_rpc_named_arguments, retries) do
      {:ok, results} -> Enum.map(results, fn %{result: result} -> result end)
      {:error, _} -> []
    end
  end
end
