defmodule Indexer.Fetcher.Optimism.Interop.MessageFailed do
  @moduledoc """
    Fills op_interop_messages DB table with failed messages.

    The table stores indexed interop messages which are got from `SentMessage` and `RelayedMessage` events
    (or failed relay transactions) emitted by the `L2ToL2CrossDomainMessenger` predeploy smart contract.
    The messages are scanned starting from the block number defined in INDEXER_OPTIMISM_L2_INTEROP_START_BLOCK
    env variable. If the variable is not defined, the module doesn't start.

    Each message always consists of two transactions: initial transaction on the source chain and relay transaction
    on the target chain. The initial transaction emits the `SentMessage` event, and the successful relay transaction
    emits the `RelayedMessage` event. In case of failed relay no events are emitted.
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  import EthereumJSONRPC, only: [fetch_blocks_by_range: 2, fetch_transaction_receipts: 2]
  import Explorer.Helper, only: [decode_data: 2]

  import Indexer.Fetcher.Optimism.Interop.Helper,
    only: [log_cant_get_chain_id_from_rpc: 0, log_cant_get_last_transaction_from_rpc: 1, log_last_block_numbers: 2]

  alias ABI.TypeDecoder
  alias EthereumJSONRPC.Blocks
  alias Explorer.Chain
  alias Explorer.Chain.Events.Subscriber
  alias Explorer.Chain.Optimism.InteropMessage
  alias Indexer.Fetcher.Optimism
  alias Indexer.Fetcher.Optimism.Interop.Message, as: InteropMessageFetcher
  alias Indexer.Helper

  @fetcher_name :optimism_interop_messages_failed

  # 4-byte signature of the method relayMessage((address origin, uint256 blockNumber, uint256 logIndex, uint256 timestamp, uint256 chainId), bytes _sentMessage)
  @relay_message_method "0x8d1d298f"

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
    {:ok, %{}, {:continue, args[:json_rpc_named_arguments]}}
  end

  # Initialization function which is used instead of `init` to avoid Supervisor's stop in case of any critical issues
  # during initialization. It checks the value of INDEXER_OPTIMISM_L2_INTEROP_START_BLOCK env variable, defines the
  # block range which must be scanned to handle failed relay transactions, and starts the handling loop.
  #
  # The block range is split into chunks which max size is defined by INDEXER_OPTIMISM_L2_INTEROP_BLOCKS_CHUNK_SIZE
  # env variable.
  #
  # Also, the function fetches the current chain id to use it in the handler (to write correct `init_chain_id` and
  # `relay_chain_id` fields).
  #
  # When the initialization succeeds, the `:continue` message is sent to GenServer to start the catchup loop
  # retrieving and saving historical failed transactions (and after that, it's switched to realtime mode).
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

    env = Application.get_all_env(:indexer)[Indexer.Fetcher.Optimism.Interop.Message]
    block_number = env[:start_block]

    with false <- is_nil(block_number),
         chain_id = Optimism.fetch_chain_id(),
         {:chain_id_is_nil, false} <- {:chain_id_is_nil, is_nil(chain_id)},
         Subscriber.to(:blocks, :realtime),
         {:ok, latest_block_number} =
           Helper.get_block_number_by_tag("latest", json_rpc_named_arguments, Helper.infinite_retries_number()),
         InteropMessage.remove_invalid_messages(latest_block_number),
         {:ok, last_block_number} <-
           InteropMessageFetcher.get_last_block_number(json_rpc_named_arguments, chain_id, true) do
      log_last_block_numbers(last_block_number, latest_block_number)

      Process.send(self(), :continue, [])

      {:noreply,
       %{
         start_block_number: max(block_number, last_block_number),
         end_block_number: latest_block_number,
         chunk_size: env[:blocks_chunk_size],
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
        log_cant_get_chain_id_from_rpc()
        {:stop, :normal, %{}}

      {:error, error_data} ->
        log_cant_get_last_transaction_from_rpc(error_data)
        {:stop, :normal, %{}}
    end
  end

  # Performs the main handling loop for the specified block range. The block range is split into chunks.
  # Max size of a chunk is defined by INDEXER_OPTIMISM_L2_INTEROP_BLOCKS_CHUNK_SIZE env variable.
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

        failed_relay_count = handle_failed_relays(Range.new(chunk_start, chunk_end), json_rpc_named_arguments, chain_id)

        Helper.log_blocks_chunk_handling(
          chunk_start,
          chunk_end,
          start_block_number,
          end_block_number,
          "#{failed_relay_count} failed relay(s).",
          :L2
        )

        reorg_block_number = Optimism.handle_reorgs_queue(__MODULE__, &InteropMessageFetcher.handle_reorg/1)

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
        Optimism.log_catchup_loop_finished(start_block_number, end_block_number)
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
    Optimism.handle_realtime_blocks(blocks, state)
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # Searches and handles failed relay transactions.
  #
  # ## Parameters
  # - `block_range`: The block range for which we need to search and handle the transactions.
  #                  Note that the length of the range cannot be larger than max batch request size on RPC node.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  # - `current_chain_id`: The current chain ID to check that `relay_chain_id` is correct.
  #
  # ## Returns
  # - The number of found transactions in the given block range.
  @spec handle_failed_relays(Range.t(), EthereumJSONRPC.json_rpc_named_arguments(), non_neg_integer()) ::
          non_neg_integer()
  defp handle_failed_relays(block_range, json_rpc_named_arguments, current_chain_id) do
    case fetch_blocks_by_range(block_range, json_rpc_named_arguments) do
      {:ok, %Blocks{transactions_params: transactions_params, errors: []}} ->
        transactions_params
        |> transactions_filter(json_rpc_named_arguments)
        |> handle_failed_relays_inner(current_chain_id)

      {_, message_or_errors} ->
        message =
          case message_or_errors do
            %Blocks{errors: errors} -> errors
            msg -> msg
          end

        Optimism.log_error_message_with_retry_sleep(
          "Cannot fetch blocks #{inspect(block_range)}. Error(s): #{inspect(message)}"
        )

        handle_failed_relays(
          block_range,
          json_rpc_named_arguments,
          current_chain_id
        )
    end
  end

  # Parses failed relay transactions and imports them to database.
  #
  # ## Parameters
  # - `transactions_params`: The list of transactions filtered by the `transactions_filter` function.
  # - `current_chain_id`: The current chain ID to check that `relay_chain_id` is correct.
  #
  # ## Returns
  # - The number of failed relay transactions imported into the `op_interop_messages` table.
  @spec handle_failed_relays_inner(list(), non_neg_integer()) :: non_neg_integer()
  defp handle_failed_relays_inner(transactions_params, current_chain_id) do
    relay_message_selector = %ABI.FunctionSelector{
      function: "relayMessage",
      types: [
        {:tuple,
         [
           :address,
           {:uint, 256},
           {:uint, 256},
           {:uint, 256},
           {:uint, 256}
         ]},
        :bytes
      ]
    }

    sent_message_event_signature = InteropMessageFetcher.sent_message_event_signature()

    messages =
      transactions_params
      |> Enum.map(fn transaction ->
        @relay_message_method <> encoded_params = transaction.input

        [
          {_origin, _block_number, _log_index, _timestamp, init_chain_id},
          ^sent_message_event_signature <> sent_message_topics_and_data
        ] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            relay_message_selector
          )

        [relay_chain_id, _target, nonce, _sender, _payload] =
          decode_data(sent_message_topics_and_data, [{:uint, 256}, :address, {:uint, 256}, :address, :bytes])

        %{
          nonce: nonce,
          init_chain_id: init_chain_id,
          block_number: transaction.block_number,
          relay_chain_id: relay_chain_id,
          relay_transaction_hash: transaction.hash,
          failed: true
        }
      end)
      |> Enum.filter(&(&1.relay_chain_id == current_chain_id))
      |> Enum.reject(&(&1.init_chain_id > InteropMessageFetcher.max_int32()))

    {:ok, _} =
      Chain.import(%{
        optimism_interop_messages: %{params: messages},
        timeout: :infinity
      })

    Enum.count(messages)
  end

  # Filters the given list of transactions leaving only failed `relayMessage` calls.
  #
  # ## Parameters
  # - `transactions_params`: The list of transactions returned by the `fetch_blocks_by_range` function.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - The filtered list of transactions.
  @spec transactions_filter(list(), EthereumJSONRPC.json_rpc_named_arguments()) :: list()
  defp transactions_filter(transactions_params, json_rpc_named_arguments) do
    relay_message_transactions =
      transactions_params
      |> Enum.filter(fn transaction ->
        to_address_hash = Map.get(transaction, :to_address_hash, "")

        to_address =
          if is_nil(to_address_hash) do
            ""
          else
            String.downcase(to_address_hash)
          end

        is_relay_message_method =
          transaction
          |> Map.get(:input, "")
          |> String.downcase()
          |> String.starts_with?(@relay_message_method)

        to_address == InteropMessageFetcher.l2tol2_cross_domain_messenger() and is_relay_message_method
      end)

    case fetch_transaction_receipts(relay_message_transactions, json_rpc_named_arguments) do
      {:ok, %{receipts: receipts}} ->
        status_by_hash =
          receipts
          |> Enum.map(&{&1.transaction_hash, &1.status})
          |> Enum.into(%{})

        Enum.filter(relay_message_transactions, fn transaction ->
          Map.get(status_by_hash, transaction.hash) == :error
        end)

      {:error, reason} ->
        transaction_hashes = Enum.map(relay_message_transactions, & &1.hash)

        error_message = "Cannot fetch receipts for #{inspect(transaction_hashes)}. Reason: #{inspect(reason)}"

        Optimism.log_error_message_with_retry_sleep(error_message)

        transactions_filter(transactions_params, json_rpc_named_arguments)
    end
  end

  def fetcher_name, do: @fetcher_name
end
