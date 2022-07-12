defmodule Explorer.Repo.Migrations.CeloPendingEpochOperationsSingleFetchRewardsColumn do
  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM celo_pending_epoch_operations;
    """)

    alter table(:celo_pending_epoch_operations) do
      remove(:election_rewards, :boolean, null: false)
      remove(:fetch_epoch_rewards, :boolean, null: false)
      add(:fetch_epoch_data, :boolean, null: false)
    end
  end

  def down do
    alter table(:celo_pending_epoch_operations) do
      add(:election_rewards, :boolean, null: false)
      add(:fetch_epoch_rewards, :boolean, null: false)

      remove(:fetch_epoch_data, :boolean, null: false)
    end
  end
end
