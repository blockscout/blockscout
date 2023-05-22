defmodule Explorer.TokenTransferTokenIdMigration.Supervisor do
  @moduledoc """
  Supervises parts of token id migration process.

  Migration process algorithm:

  Defining the bounds of migration (by the first and the last block number of TokenTransfer).
  Supervisor starts the workers in amount equal to 'TOKEN_ID_MIGRATION_CONCURRENCY' env value (defaults to 1)
  and the 'LowestBlockNumberUpdater'.

  Each worker goes through the token transfers by batches ('TOKEN_ID_MIGRATION_BATCH_SIZE', defaults to 500)
  and updates the token_ids to be equal of [token_id] for transfers that has any token_id.
  Worker goes from the newest blocks to latest.
  After worker is done with current batch, it sends the information about processed batch to 'LowestBlockNumberUpdater'
  and takes the next by defining its bounds based on amount of all workers.

  For example, if batch size is 10, we have 5 workers and 100 items to be processed,
  the distribution will be like this:
  1 worker - 99..90, 49..40
  2 worker - 89..80, 39..30
  3 worker - 79..70, 29..20
  4 worker - 69..60, 19..10
  5 worker - 59..50, 9..0

  'LowestBlockNumberUpdater' keeps the information about the last processed block number
  (which is stored in the 'token_transfer_token_id_migrator_progress' db entity)
  and block ranges that has already been processed by the workers but couldn't be committed
  to last processed block number yet (because of the possible gap between the current last block
  and upper bound of the last processed batch). Uncommitted block numbers are stored in normalize ranges.
  When there is no gap between the last processed block number and the upper bound of the upper range,
  'LowestBlockNumberUpdater' updates the last processed block number in db and drops this range from its state.

  This supervisor won't start if the migration is completed
  (last processed block number in db == 'TOKEN_ID_MIGRATION_FIRST_BLOCK' (defaults to 0)).
  """
  use Supervisor

  alias Explorer.TokenTransferTokenIdMigration.{LowestBlockNumberUpdater, Worker}
  alias Explorer.Utility.TokenTransferTokenIdMigratorProgress

  @default_first_block 0
  @default_workers_count 1

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    first_block = Application.get_env(:explorer, :token_id_migration)[:first_block] || @default_first_block
    last_block = TokenTransferTokenIdMigratorProgress.get_last_processed_block_number()

    if last_block > first_block do
      workers_count = Application.get_env(:explorer, :token_id_migration)[:concurrency] || @default_workers_count

      workers =
        Enum.map(1..workers_count, fn id ->
          Supervisor.child_spec(
            {Worker, idx: id, first_block: first_block, last_block: last_block, step: workers_count - 1},
            id: {Worker, id},
            restart: :transient
          )
        end)

      Supervisor.init([LowestBlockNumberUpdater | workers], strategy: :one_for_one)
    else
      :ignore
    end
  end
end
