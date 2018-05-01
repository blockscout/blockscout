defmodule Explorer.Indexer.BlockFetcher do
  @moduledoc """
  TODO

  ## Next steps

  - after gensis index transition to RT index
  """

  use GenServer

  require Logger

  alias Explorer.{Chain, Indexer, JSONRPC}
  alias Explorer.Indexer.Sequence
  alias Explorer.JSONRPC.Transactions

  # Struct

  defstruct ~w(current_block genesis_task subscription_id)a

  # Constants

  @batch_size 50
  @blocks_concurrency 20

  @internal_batch_size 50
  @internal_concurrency 8

  @polling_interval 20_000

  @receipts_batch_size 250
  @receipts_concurrency 20

  # Functions

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## GenServer callbacks

  @impl GenServer

  def handle_info(:index, state) do
    {count, missing_ranges} = missing_block_numbers()
    current_block = Indexer.next_block_number()

    Logger.debug(fn -> "#{count} missed block ranges between genesis and #{current_block}" end)

    {:ok, genesis_task} =
      Task.start_link(fn ->
        stream_import(missing_ranges, current_block)
      end)

    Process.monitor(genesis_task)

    {:noreply, %__MODULE__{state | genesis_task: genesis_task}}
  end

  def handle_info(:poll, %__MODULE__{subscription_id: subscription_id} = state) do
    Process.send_after(self(), :poll, @polling_interval)

    with {:ok, blocks} when length(blocks) > 0 <- JSONRPC.check_for_updates(subscription_id) do
      Logger.debug(fn -> "Processing #{length(blocks)} new block(s)" end)

      # TODO do something with the new blocks
      JSONRPC.fetch_blocks_by_hash(blocks)
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, :normal}, %__MODULE__{genesis_task: pid} = state) do
    Logger.info(fn -> "Finished index from genesis" end)

    {:ok, subscription_id} = JSONRPC.listen_for_new_blocks()

    send(self(), :poll)

    {:noreply, %__MODULE__{state | genesis_task: nil, subscription_id: subscription_id}}
  end

  def handle_info(:debug_count, state) do
    Logger.debug(fn ->
      """

      ================================
      persisted counts
      ================================
        blocks: #{Chain.block_count()}
        internal transactions: #{Chain.internal_transaction_count()}
        receipts: #{Chain.receipt_count()}
        logs: #{Chain.log_count()}
      """
    end)

    {:noreply, state}
  end

  @impl GenServer
  def init(_opts) do
    send(self(), :index)
    :timer.send_interval(15_000, self(), :debug_count)

    {:ok, %__MODULE__{current_block: 0, genesis_task: nil, subscription_id: nil}}
  end

  ## Private Functions

  defp cap_seq(seq, :end_of_chain, {_block_start, block_end}) do
    Logger.info("Reached end of blockchain #{inspect(block_end)}")
    :ok = Sequence.cap(seq)
  end

  defp cap_seq(_seq, :more, {block_start, block_end}) do
    Logger.debug(fn -> "got blocks #{block_start} - #{block_end}" end)
    :ok
  end

  defp fetch_internal_transactions([]), do: {:ok, []}

  defp fetch_internal_transactions(hashes) do
    Logger.debug(fn -> "fetching #{length(hashes)} internal transactions" end)
    stream_opts = [max_concurrency: @internal_concurrency, timeout: :infinity]

    hashes
    |> Enum.chunk_every(@internal_batch_size)
    |> Task.async_stream(&JSONRPC.fetch_internal_transactions(&1), stream_opts)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, internal_transactions_params}}, {:ok, acc} -> {:cont, {:ok, acc ++ internal_transactions_params}}
      {:ok, {:error, reason}}, {:ok, _acc} -> {:halt, {:error, reason}}
      {:error, reason}, {:ok, _acc} -> {:halt, {:error, reason}}
    end)
  end

  defp fetch_transaction_receipts([]), do: {:ok, %{logs_params: [], receipts_params: []}}

  defp fetch_transaction_receipts(hashes) do
    Logger.debug(fn -> "fetching #{length(hashes)} transaction receipts" end)
    stream_opts = [max_concurrency: @receipts_concurrency, timeout: :infinity]

    hashes
    |> Enum.chunk_every(@receipts_batch_size)
    |> Task.async_stream(&JSONRPC.fetch_transaction_receipts(&1), stream_opts)
    |> Enum.reduce_while({:ok, %{logs_params: [], receipts_params: []}}, fn
      {:ok, {:ok, %{logs_params: logs_params, receipts_params: receipts_params}}},
      {:ok, %{logs_params: acc_log_params, receipts_params: acc_receipts_params}} ->
        {:cont,
         {:ok, %{logs_params: acc_log_params ++ logs_params, receipts_params: acc_receipts_params ++ receipts_params}}}

      {:ok, {:error, reason}}, {:ok, _acc} ->
        {:halt, {:error, reason}}

      {:error, reason}, {:ok, _acc} ->
        {:halt, {:error, reason}}
    end)
  end

  defp insert(%{
         blocks_params: blocks_params,
         internal_transactions_params: internal_transactions_params,
         logs_params: log_params,
         range: range,
         receipts_params: receipt_params,
         seq: seq,
         transactions_params: transactions_params
       }) do
    case Chain.insert(%{
           blocks_params: blocks_params,
           internal_transactions_params: internal_transactions_params,
           logs_params: log_params,
           receipts_params: receipt_params,
           transactions_params: transactions_params
         }) do
      {:ok, _results} ->
        :ok

      {:error, step, reason, _changes} ->
        Logger.debug(fn ->
          "failed to insert blocks during #{step} #{inspect(range)}: #{inspect(reason)}. Retrying"
        end)

        :ok = Sequence.inject_range(seq, range)
    end
  end

  defp missing_block_numbers do
    {count, missing_ranges} = Chain.missing_block_numbers()

    chunked_ranges =
      Enum.flat_map(missing_ranges, fn
        {start, ending} when ending - start <= @batch_size ->
          [{start, ending}]

        {start, ending} ->
          start
          |> Stream.iterate(&(&1 + @batch_size))
          |> Enum.reduce_while([], fn
            chunk_start, acc when chunk_start + @batch_size >= ending ->
              {:halt, [{chunk_start, ending} | acc]}

            chunk_start, acc ->
              {:cont, [{chunk_start, chunk_start + @batch_size - 1} | acc]}
          end)
          |> Enum.reverse()
      end)

    {count, chunked_ranges}
  end

  defp stream_import(missing_ranges, current_block) do
    {:ok, seq} = Sequence.start_link(missing_ranges, current_block, @batch_size)

    seq
    |> Sequence.build_stream()
    |> Task.async_stream(
      fn {block_start, block_end} = range ->
        with {:ok, value} <- JSONRPC.fetch_blocks_by_range(block_start, block_end),
             # `mix format` bug made the line too long when pattern combined into above line
             %{next: next, blocks_params: blocks_params, range: range, transactions_params: transactions_params} =
               value,
             :ok <- cap_seq(seq, next, range),
             transaction_hashes <- Transactions.params_to_hashes(transactions_params),
             {:ok, %{logs_params: logs_params, receipts_params: receipts_params}} <-
               fetch_transaction_receipts(transaction_hashes),
             {:ok, internal_transactions_params} <- fetch_internal_transactions(transaction_hashes) do
          insert(%{
            blocks_params: blocks_params,
            internal_transactions_params: internal_transactions_params,
            logs_params: logs_params,
            range: range,
            receipts_params: receipts_params,
            seq: seq,
            transactions_params: transactions_params
          })
        else
          {:error, reason} ->
            Logger.debug(fn ->
              "failed to fetch blocks #{inspect(range)}: #{inspect(reason)}. Retrying"
            end)

            :ok = Sequence.inject_range(seq, range)
        end
      end,
      max_concurrency: @blocks_concurrency,
      timeout: :infinity
    )
    |> Enum.each(fn {:ok, :ok} -> :ok end)
  end
end
