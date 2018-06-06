defmodule Explorer.Indexer.BlockFetcher do
  @moduledoc """
  Fetches and indexes block ranges from gensis to realtime.
  """

  use GenServer

  require Logger

  import Explorer.Indexer, only: [debug: 1]

  alias EthereumJSONRPC
  alias EthereumJSONRPC.Transactions
  alias Explorer.{BufferedTask, Chain, Indexer}
  alias Explorer.Indexer.{AddressBalanceFetcher, AddressExtraction, InternalTransactionFetcher, Sequence}

  # dialyzer thinks that Logger.debug functions always have no_local_return
  @dialyzer {:nowarn_function, import_range: 3}

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @blocks_batch_size 10
  @blocks_concurrency 10

  # milliseconds
  @block_rate 5_000

  @receipts_batch_size 250
  @receipts_concurrency 10

  @doc false
  def default_blocks_batch_size, do: @blocks_batch_size

  @doc """
  Starts the server.

  ## Options

  Default options are pulled from application config under the
  `:explorer, :indexer` keyspace. The follow options can be overridden:

    * `:blocks_batch_size` - The number of blocks to request in one call to the JSONRPC.  Defaults to
      `#{@blocks_batch_size}`.  Block requests also include the transactions for those blocks.  *These transactions
      are not paginated.*
    * `:blocks_concurrency` - The number of concurrent requests of `:blocks_batch_size` to allow against the JSONRPC.
      Defaults to #{@blocks_concurrency}.  So upto `blocks_concurrency * block_batch_size` (defaults to
      `#{@blocks_concurrency * @blocks_batch_size}`) blocks can be requested from the JSONRPC at once over all
      connections.
    * `:block_rate` - The millisecond rate new blocks are published at. Defaults to `#{@block_rate}` milliseconds.
    * `:receipts_batch_size` - The number of receipts to request in one call to the JSONRPC.  Defaults to
      `#{@receipts_batch_size}`.  Receipt requests also include the logs for when the transaction was collated into the
      block.  *These logs are not paginated.*
    * `:receipts_concurrency` - The number of concurrent requests of `:receipts_batch_size` to allow against the JSONRPC
      **for each block range**. Defaults to `#{@receipts_concurrency}`.  So upto
      `block_concurrency * receipts_batch_size * receipts_concurrency` (defaults to
      `#{@blocks_concurrency * @receipts_concurrency * @receipts_batch_size}`) receipts can be requested from the
      JSONRPC at once over all connections. *Each transaction only has one receipt.*
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    opts = Keyword.merge(Application.fetch_env!(:explorer, :indexer), opts)
    :timer.send_interval(15_000, self(), :debug_count)

    state = %{
      genesis_task: nil,
      realtime_task: nil,
      realtime_interval: (opts[:block_rate] || @block_rate) * 2,
      starting_block_number: nil,
      blocks_batch_size: Keyword.get(opts, :blocks_batch_size, @blocks_batch_size),
      blocks_concurrency: Keyword.get(opts, :blocks_concurrency, @blocks_concurrency),
      receipts_batch_size: Keyword.get(opts, :receipts_batch_size, @receipts_batch_size),
      receipts_concurrency: Keyword.get(opts, :receipts_concurrency, @receipts_concurrency)
    }

    scheduled_state =
      state
      |> schedule_next_catchup_index()
      |> schedule_next_realtime_fetch()

    {:ok, scheduled_state}
  end

  @impl GenServer
  def handle_info(:catchup_index, %{} = state) do
    {:ok, genesis_task, _ref} = Indexer.start_monitor(fn -> genesis_task(state) end)

    {:noreply, %{state | genesis_task: genesis_task}}
  end

  def handle_info(:realtime_index, %{} = state) do
    {:ok, realtime_task, _ref} = Indexer.start_monitor(fn -> realtime_task(state) end)

    {:noreply, %{state | realtime_task: realtime_task}}
  end

  def handle_info({:DOWN, _ref, :process, pid, :normal}, %{realtime_task: pid} = state) do
    {:noreply, schedule_next_realtime_fetch(%{state | realtime_task: nil})}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{realtime_task: pid} = state) do
    Logger.error(fn -> "realtime index stream exited. Restarting" end)
    {:noreply, schedule_next_realtime_fetch(%{state | realtime_task: nil})}
  end

  def handle_info({:DOWN, _ref, :process, pid, :normal}, %{genesis_task: pid} = state) do
    Logger.info(fn -> "Finished index from genesis. Transitioning to only realtime index." end)
    {:noreply, %{state | genesis_task: nil}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{genesis_task: pid} = state) do
    Logger.error(fn -> "gensis index stream exited. Restarting" end)

    {:noreply, schedule_next_catchup_index(%{state | genesis_task: nil})}
  end

  def handle_info(:debug_count, %{} = state) do
    debug(fn ->
      """

      ================================
      persisted counts
      ================================
        addresses: #{Chain.address_count()}
        blocks: #{Chain.block_count()}
        internal transactions: #{Chain.internal_transaction_count()}
        logs: #{Chain.log_count()}
        addresses: #{Chain.address_count()}

      ================================
      deferred fetches
      ================================
        address balances: #{inspect(BufferedTask.debug_count(AddressBalanceFetcher))}
        internal transactions: #{inspect(BufferedTask.debug_count(InternalTransactionFetcher))}
      """
    end)

    {:noreply, state}
  end

  defp cap_seq(seq, next, range) do
    case next do
      :more ->
        debug(fn ->
          first_block_number..last_block_number = range
          "got blocks #{first_block_number} - #{last_block_number}"
        end)

      :end_of_chain ->
        Sequence.cap(seq)
    end

    :ok
  end

  defp fetch_transaction_receipts(_state, []), do: {:ok, %{logs: [], receipts: []}}

  defp fetch_transaction_receipts(%{} = state, hashes) do
    debug(fn -> "fetching #{length(hashes)} transaction receipts" end)
    stream_opts = [max_concurrency: state.receipts_concurrency, timeout: :infinity]

    hashes
    |> Enum.chunk_every(state.receipts_batch_size)
    |> Task.async_stream(&EthereumJSONRPC.fetch_transaction_receipts(&1), stream_opts)
    |> Enum.reduce_while({:ok, %{logs: [], receipts: []}}, fn
      {:ok, {:ok, %{logs: logs, receipts: receipts}}}, {:ok, %{logs: acc_logs, receipts: acc_receipts}} ->
        {:cont, {:ok, %{logs: acc_logs ++ logs, receipts: acc_receipts ++ receipts}}}

      {:ok, {:error, reason}}, {:ok, _acc} ->
        {:halt, {:error, reason}}

      {:error, reason}, {:ok, _acc} ->
        {:halt, {:error, reason}}
    end)
  end

  defp genesis_task(%{} = state) do
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest")
    missing_ranges = missing_block_number_ranges(state, latest_block_number..0)
    count = Enum.count(missing_ranges)

    debug(fn -> "#{count} missed block ranges between #{latest_block_number} and genesis" end)

    {:ok, seq} = Sequence.start_link(missing_ranges, latest_block_number, -1 * state.blocks_batch_size)
    stream_import(state, seq, max_concurrency: state.blocks_concurrency)
  end

  defp insert(seq, range, options) when is_list(options) do
    with {:ok, results} <- Chain.import_blocks(options) do
      async_import_remaining_block_data(results)
      {:ok, results}
    else
      {:error, step, failed_value, _changes_so_far} = error ->
        debug(fn ->
          "failed to insert blocks during #{step} #{inspect(range)}: #{inspect(failed_value)}. Retrying"
        end)

        :ok = Sequence.inject_range(seq, range)

        error
    end
  end

  defp async_import_remaining_block_data(results) do
    %{transactions: transaction_hashes, addresses: address_hashes} = results

    AddressBalanceFetcher.async_fetch_balances(address_hashes)
    InternalTransactionFetcher.async_fetch(transaction_hashes, 10_000)
  end

  defp missing_block_number_ranges(%{blocks_batch_size: blocks_batch_size}, range) do
    range
    |> Chain.missing_block_number_ranges()
    |> chunk_ranges(blocks_batch_size)
  end

  defp chunk_ranges(ranges, size) do
    Enum.flat_map(ranges, fn
      first..last = range when last - first <= size ->
        [range]

      first..last ->
        first
        |> Stream.iterate(&(&1 + size))
        |> Enum.reduce_while([], fn
          chunk_first, acc when chunk_first + size >= last ->
            {:halt, [chunk_first..last | acc]}

          chunk_first, acc ->
            chunk_last = chunk_first + size - 1
            {:cont, [chunk_first..chunk_last | acc]}
        end)
        |> Enum.reverse()
    end)
  end

  defp realtime_task(%{} = state) do
    {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest")
    {:ok, seq} = Sequence.start_link([], latest_block_number, 2)
    stream_import(state, seq, max_concurrency: 1)
  end

  defp stream_import(state, seq, task_opts) do
    seq
    |> Sequence.build_stream()
    |> Task.async_stream(
      &import_range(&1, state, seq),
      Keyword.merge(task_opts, timeout: :infinity)
    )
    |> Stream.run()
  end

  # Run at state.blocks_concurrency max_concurrency when called by `stream_import/3`
  # Only public for testing
  @doc false
  def import_range(range, %{} = state, seq) do
    with {:blocks, {:ok, next, result}} <- {:blocks, EthereumJSONRPC.fetch_blocks_by_range(range)},
         %{blocks: blocks, transactions: transactions_without_receipts} = result,
         cap_seq(seq, next, range),
         transaction_hashes = Transactions.params_to_hashes(transactions_without_receipts),
         {:receipts, {:ok, receipt_params}} <- {:receipts, fetch_transaction_receipts(state, transaction_hashes)},
         %{logs: logs, receipts: receipts} = receipt_params,
         transactions_with_receipts = put_receipts(transactions_without_receipts, receipts) do
      addresses =
        AddressExtraction.extract_addresses(%{
          blocks: blocks,
          logs: logs,
          transactions: transactions_with_receipts
        })

      insert(
        seq,
        range,
        addresses: [params: addresses],
        blocks: [params: blocks],
        logs: [params: logs],
        receipts: [params: receipts],
        transactions: [params: transactions_with_receipts]
      )
    else
      {step, {:error, reason}} ->
        debug(fn ->
          first..last = range
          "failed to fetch #{step} for blocks #{first} - #{last}: #{inspect(reason)}. Retrying block range."
        end)

        :ok = Sequence.inject_range(seq, range)

        {:error, step, reason}
    end
  end

  defp put_receipts(transactions_params, receipts_params)
       when is_list(transactions_params) and is_list(receipts_params) do
    transaction_hash_to_receipt_params =
      Enum.into(receipts_params, %{}, fn %{transaction_hash: transaction_hash} = receipt_params ->
        {transaction_hash, receipt_params}
      end)

    Enum.map(transactions_params, fn %{hash: transaction_hash} = transaction_params ->
      Map.merge(transaction_params, Map.fetch!(transaction_hash_to_receipt_params, transaction_hash))
    end)
  end

  defp schedule_next_catchup_index(state) do
    send(self(), :catchup_index)
    state
  end

  defp schedule_next_realtime_fetch(state) do
    Process.send_after(self(), :realtime_index, state.realtime_interval)
    state
  end
end
