defmodule Indexer.Fetcher.TokenTransferTokenIdMigration.Supervisor do
  use Supervisor

  alias Explorer.Utility.TokenTransferTokenIdMigratorProgress
  alias Indexer.Fetcher.TokenTransferTokenIdMigration.LowestBlockNumberUpdater
  alias Indexer.Fetcher.TokenTransferTokenIdMigration.Worker

  @default_first_block 0
  @default_workers_count 1

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    first_block = Application.get_env(:indexer, :token_id_migration)[:first_block] || @default_first_block
    last_block = TokenTransferTokenIdMigratorProgress.get_last_processed_block_number()

    if last_block > first_block do
      workers_count = Application.get_env(:indexer, :token_id_migration)[:concurrency] || @default_workers_count

      workers =
        Enum.map(1..workers_count, fn id ->
          worker_name = build_worker_name(id)

          Supervisor.child_spec(
            {Worker,
             idx: id, first_block: first_block, last_block: last_block, step: workers_count - 1, name: worker_name},
            id: worker_name,
            restart: :transient
          )
        end)

      Supervisor.init([LowestBlockNumberUpdater | workers], strategy: :one_for_one)
    else
      :ignore
    end
  end

  defp build_worker_name(worker_id), do: :"#{Worker}_#{worker_id}"
end
