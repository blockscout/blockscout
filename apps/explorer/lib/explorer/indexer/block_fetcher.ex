defmodule Explorer.Indexer.BlockFetcher do
  @moduledoc """
  Fetches and indexes block ranges from gensis to realtime.
  """

  use GenServer

  require Logger

  alias Explorer.{Chain, Indexer, JSONRPC}

  alias Explorer.Indexer.{
    Sequence,
    BlockImporter
  }

  alias Explorer.JSONRPC.Transactions

  # dialyzer thinks that Logger.debug functions always have no_local_return
  @dialyzer {:nowarn_function, import_range: 3}

  @blocks_batch_size 10
  @blocks_concurrency 10

  @internal_batch_size 50
  @internal_concurrency 8

  @block_rate 5_000

  @receipts_batch_size 250
  @receipts_concurrency 20

  @doc """
  Starts the server.

  ## Options

  Default options are pulled from application config under the
  `:explorer, :indexer` keyspace. The follow options can be overridden:

    * `:debug_logs` - When `true` logs verbose index progress. Defaults `false`.
    * `:block_rate` - The millisecond rate new blocks are published at.
      Defaults to `#{@block_rate}`.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    opts = Keyword.merge(Application.fetch_env!(:explorer, :indexer), opts)

    send(self(), :catchup_index)
    :timer.send_interval(15_000, self(), :debug_count)

    state = %{
      genesis_task: nil,
      debug_logs: Keyword.get(opts, :debug_logs, false),
      realtime_interval: (opts[:block_rate] || @block_rate) * 2,
      blocks_batch_size: Keyword.get(opts, :blocks_batch_size, @blocks_batch_size),
      blocks_concurrency: Keyword.get(opts, :blocks_concurrency, @blocks_concurrency)
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:catchup_index, state) do
    {count, missing_ranges} = missing_block_numbers(state)
    current_block = Indexer.next_block_number()

    debug(state, fn -> "#{count} missed block ranges between genesis and #{current_block}" end)

    {:ok, genesis_task} =
      Task.start_link(fn ->
        {:ok, seq} = Sequence.start_link(missing_ranges, current_block, state.blocks_batch_size)
        stream_import(state, seq, max_concurrency: state.blocks_concurrency)
      end)

    Process.monitor(genesis_task)

    {:noreply, %{state | genesis_task: genesis_task}}
  end

  def handle_info(:realtime_index, state) do
    {:ok, realtime_task} =
      Task.start_link(fn ->
        {:ok, seq} = Sequence.start_link([], Indexer.next_block_number(), 2)
        stream_import(state, seq, max_concurrency: 1)
      end)

    Process.monitor(realtime_task)

    {:noreply, %{state | realtime_task: realtime_task}}
  end

  def handle_info({:DOWN, _ref, :process, pid, :normal}, %{realtime_task: pid} = state) do
    {:noreply, schedule_next_realtime_fetch(%{state | realtime_task: nil})}
  end

  def handle_info({:DOWN, _ref, :process, pid, :normal}, %{genesis_task: pid} = state) do
    Logger.info(fn -> "Finished index from genesis. Transitioning to realtime index." end)
    {:noreply, schedule_next_realtime_fetch(%{state | genesis_task: nil})}
  end

  def handle_info(:debug_count, state) do
    debug(state, fn ->
      """

      ================================
      persisted counts
      ================================
        blocks: #{Chain.block_count()}
        internal transactions: #{Chain.internal_transaction_count()}
        receipts: #{Chain.receipt_count()}
        logs: #{Chain.log_count()}
        addresses: #{Chain.address_count()}
      """
    end)

    {:noreply, state}
  end

  defp cap_seq(seq, :end_of_chain, {_block_start, _block_end}, _state) do
    :ok = Sequence.cap(seq)
  end

  defp cap_seq(_seq, :more, {block_start, block_end}, state) do
    debug(state, fn -> "got blocks #{block_start} - #{block_end}" end)
    :ok
  end

  defp fetch_internal_transactions(_state, []), do: {:ok, []}

  defp fetch_internal_transactions(state, hashes) do
    debug(state, fn -> "fetching #{length(hashes)} internal transactions" end)
    stream_opts = [max_concurrency: @internal_concurrency, timeout: :infinity]

    hashes
    |> Enum.chunk_every(@internal_batch_size)
    |> Task.async_stream(&JSONRPC.fetch_internal_transactions(&1), stream_opts)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, internal_transactions}}, {:ok, acc} -> {:cont, {:ok, acc ++ internal_transactions}}
      {:ok, {:error, reason}}, {:ok, _acc} -> {:halt, {:error, reason}}
      {:error, reason}, {:ok, _acc} -> {:halt, {:error, reason}}
    end)
  end

  defp fetch_transaction_receipts(_state, []), do: {:ok, %{logs: [], receipts: []}}

  defp fetch_transaction_receipts(state, hashes) do
    debug(state, fn -> "fetching #{length(hashes)} transaction receipts" end)
    stream_opts = [max_concurrency: @receipts_concurrency, timeout: :infinity]

    hashes
    |> Enum.chunk_every(@receipts_batch_size)
    |> Task.async_stream(&JSONRPC.fetch_transaction_receipts(&1), stream_opts)
    |> Enum.reduce_while({:ok, %{logs: [], receipts: []}}, fn
      {:ok, {:ok, %{logs: logs, receipts: receipts}}}, {:ok, %{logs: acc_logs, receipts: acc_receipts}} ->
        {:cont, {:ok, %{logs: acc_logs ++ logs, receipts: acc_receipts ++ receipts}}}

      {:ok, {:error, reason}}, {:ok, _acc} ->
        {:halt, {:error, reason}}

      {:error, reason}, {:ok, _acc} ->
        {:halt, {:error, reason}}
    end)
  end

  defp insert(state, seq, range, params) do
    case BlockImporter.import_blocks(params) do
      :ok ->
        :ok

      {:error, step, reason} ->
        debug(state, fn ->
          "failed to insert blocks during #{step} #{inspect(range)}: #{inspect(reason)}. Retrying"
        end)

        :ok = Sequence.inject_range(seq, range)
    end
  end

  defp missing_block_numbers(%{blocks_batch_size: blocks_batch_size}) do
    {count, missing_ranges} = Chain.missing_block_numbers()

    chunked_ranges =
      Enum.flat_map(missing_ranges, fn
        {start, ending} when ending - start <= blocks_batch_size ->
          [{start, ending}]

        {start, ending} ->
          start
          |> Stream.iterate(&(&1 + blocks_batch_size))
          |> Enum.reduce_while([], fn
            chunk_start, acc when chunk_start + blocks_batch_size >= ending ->
              {:halt, [{chunk_start, ending} | acc]}

            chunk_start, acc ->
              {:cont, [{chunk_start, chunk_start + blocks_batch_size - 1} | acc]}
          end)
          |> Enum.reverse()
      end)

    {count, chunked_ranges}
  end

  defp stream_import(state, seq, task_opts) do
    seq
    |> Sequence.build_stream()
    |> Task.async_stream(&import_range(&1, state, seq), Keyword.merge(task_opts, timeout: :infinity))
    |> Enum.each(fn {:ok, :ok} -> :ok end)
  end

  defp import_range({block_start, block_end} = range, state, seq) do
    with {:blocks, {:ok, next, result}} <- {:blocks, JSONRPC.fetch_blocks_by_range(block_start, block_end)},
         %{blocks: blocks, transactions: transactions} = result,
         cap_seq(seq, next, range, state),
         transaction_hashes = Transactions.params_to_hashes(transactions),
         {:receipts, {:ok, receipt_params}} <- {:receipts, fetch_transaction_receipts(state, transaction_hashes)},
         %{logs: logs, receipts: receipts} = receipt_params,
         {:internal_transactions, {:ok, internal_transactions}} <-
           {:internal_transactions, fetch_internal_transactions(state, transaction_hashes)} do
      insert(state, seq, range, %{
        blocks: blocks,
        internal_transactions: internal_transactions,
        logs: logs,
        receipts: receipts,
        transactions: transactions
      })
    else
      {step, {:error, reason}} ->
        debug(state, fn ->
          "failed to fetch #{step} for blocks #{block_start} - #{block_end}: #{inspect(reason)}. Retrying block range."
        end)

        :ok = Sequence.inject_range(seq, range)
    end
  end

  defp schedule_next_realtime_fetch(state) do
    timer = Process.send_after(self(), :realtime_index, state.realtime_interval)
    %{state | poll_timer: timer}
  end

  defp debug(%{debug_logs: true}, func), do: Logger.debug(func)
  defp debug(%{debug_logs: false}, _func), do: :noop
end
