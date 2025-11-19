defmodule Indexer.Fetcher.InternalTransaction.DeleteQueue do
  @moduledoc """
  Deletes internal transactions for block from the queue and inserts new pending operations for them.
  """

  require Logger

  use Indexer.Fetcher, restart: :permanent

  import Ecto.Query

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.{
    Block,
    InternalTransaction,
    PendingBlockOperation,
    PendingOperationsHelper,
    PendingTransactionOperation
  }

  alias Explorer.Chain.InternalTransaction.DeleteQueue
  alias Explorer.Helper, as: ExplorerHelper
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.InternalTransaction, as: InternalTransactionFetcher
  alias Indexer.Helper, as: IndexerHelper

  @behaviour BufferedTask

  @default_max_batch_size 100
  @default_max_concurrency 1
  @default_threshold :timer.minutes(10)

  @doc false
  def child_spec([init_options, gen_server_options]) do
    merged_init_opts =
      defaults()
      |> Keyword.merge(init_options)
      |> Keyword.put_new(:state, [])

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial_acc, reducer, _) do
    {:ok, acc} =
      DeleteQueue.stream_data(
        initial_acc,
        fn data, acc ->
          IndexerHelper.reduce_if_queue_is_not_full(data, acc, reducer, __MODULE__)
        end,
        Application.get_env(:indexer, __MODULE__)[:threshold] || @default_threshold
      )

    acc
  end

  @impl BufferedTask
  def run(block_numbers, _state) when is_list(block_numbers) do
    result =
      Repo.transaction(fn ->
        DeleteQueue
        |> where([dq], dq.block_number in ^block_numbers)
        |> Repo.delete_all(timeout: :infinity)

        InternalTransaction
        |> where([it], it.block_number in ^block_numbers)
        |> Repo.delete_all(timeout: :infinity)

        insert_pending_operations(block_numbers)
      end)

    case result do
      {:ok, {block_numbers, transactions}} ->
        if not is_nil(Process.whereis(InternalTransactionFetcher)) do
          InternalTransactionFetcher.async_fetch(block_numbers, transactions, true)
        end

        :ok

      {:error, error} ->
        Logger.error("Unable to clean internal transactions for reorg: #{inspect(error)}")
        {:retry, block_numbers}
    end
  end

  defp insert_pending_operations(block_numbers) do
    case PendingOperationsHelper.pending_operations_type() do
      "transactions" ->
        transactions = Chain.get_transactions_of_block_numbers(block_numbers)

        pto_params =
          transactions
          |> Enum.map(&%{transaction_hash: &1.hash})
          |> ExplorerHelper.add_timestamps()

        Repo.insert_all(PendingTransactionOperation, pto_params, on_conflict: :nothing)
        {[], transactions}

      "blocks" ->
        pbo_params =
          Block
          |> where([b], b.number in ^block_numbers)
          |> where([b], b.consensus == true)
          |> select([b], %{block_hash: b.hash, block_number: b.number})
          |> Repo.all()
          |> ExplorerHelper.add_timestamps()

        {_total, inserted} =
          Repo.insert_all(PendingBlockOperation, pbo_params, on_conflict: :nothing, returning: [:block_number])

        {Enum.map(inserted, & &1.block_number), []}
    end
  end

  defp defaults do
    [
      flush_interval: :timer.seconds(10),
      max_concurrency: Application.get_env(:indexer, __MODULE__)[:concurrency] || @default_max_concurrency,
      max_batch_size: Application.get_env(:indexer, __MODULE__)[:batch_size] || @default_max_batch_size,
      task_supervisor: __MODULE__.TaskSupervisor
    ]
  end
end
