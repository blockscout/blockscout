defmodule Explorer.Repo.Migrations.AddInitialCeloPendingEpochOperationsElectionRewards do
  use Ecto.Migration

  def up do
    execute("""
    WITH epoch_blocks AS (
    SELECT i * 17280 as block_number FROM generate_series(1, (SELECT (MAX(number)/17280) FROM blocks)) as i
    ), epoch_block_numbers AS
    (SELECT b.number, true as epoch, true as election_rewards FROM epoch_blocks eb LEFT JOIN blocks b ON b.number = eb.block_number where b.number is not null)
    INSERT INTO celo_pending_epoch_operations (
    block_number, fetch_epoch_rewards, election_rewards, inserted_at, updated_at
    ) SELECT *, NOW(), NOW() FROM epoch_block_numbers;
    """)
  end

  def down do
    execute("delete from celo_pending_epoch_operations;")
  end
end
