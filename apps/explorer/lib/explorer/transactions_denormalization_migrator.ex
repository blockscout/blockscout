defmodule Explorer.TransactionsDenormalizationMigrator do
  @moduledoc """
  Migrates all transactions to have set block_consensus and block_timestamp
  """

  use GenServer, restart: :transient

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Transaction
  alias Explorer.Repo

  @default_batch_size 500
  @default_concurrency 4 * System.schedulers_online()

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def migration_finished? do
    not Repo.exists?(unprocessed_transactions_query())
  end

  @impl true
  def init(_) do
    schedule_batch_migration()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:migrate_batch, state) do
    case last_unprocessed_transaction_hashes() do
      [] ->
        BackgroundMigrations.set_denormalization_finished(true)
        {:stop, :normal, state}

      hashes ->
        hashes
        |> Enum.chunk_every(batch_size())
        |> Enum.map(&run_task/1)
        |> Task.await_many(:infinity)

        schedule_batch_migration()

        {:noreply, state}
    end
  end

  defp run_task(batch), do: Task.async(fn -> update_batch(batch) end)

  defp last_unprocessed_transaction_hashes do
    limit = batch_size() * concurrency()

    unprocessed_transactions_query()
    |> order_by(desc: :inserted_at)
    |> select([t], t.hash)
    |> limit(^limit)
    |> Repo.all()
  end

  defp unprocessed_transactions_query do
    from(t in Transaction,
      where: not is_nil(t.block_hash) and (is_nil(t.block_consensus) or is_nil(t.block_timestamp))
    )
  end

  defp update_batch(transaction_hashes) do
    query =
      from(transaction in Transaction,
        join: block in assoc(transaction, :block),
        where: transaction.hash in ^transaction_hashes,
        update: [set: [block_consensus: block.consensus, block_timestamp: block.timestamp]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  defp schedule_batch_migration do
    Process.send(self(), :migrate_batch, [])
  end

  defp batch_size do
    Application.get_env(:explorer, __MODULE__)[:batch_size] || @default_batch_size
  end

  defp concurrency do
    Application.get_env(:explorer, __MODULE__)[:batch_size] || @default_concurrency
  end
end
