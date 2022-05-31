defmodule Explorer.Repo.Migrations.CeloPendingEpochOperationsRemoveDeprecatedAndAddElectionRewards do
  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM celo_pending_epoch_operations;
    """)

    alter table(:celo_pending_epoch_operations) do
      remove(:fetch_validator_group_data, :boolean, null: false)
      remove(:fetch_voter_votes, :boolean, null: false)
      remove(:block_hash)
      add(:election_rewards, :boolean, null: false)
      add(:block_number, :bigint, null: false, primary_key: true)
    end
  end

  def down do
    alter table(:celo_pending_epoch_operations) do
      add(:fetch_validator_group_data, :boolean, null: false)
      add(:fetch_voter_votes, :boolean, null: false)

      add(:block_hash, references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      remove(:election_rewards, :boolean, null: false)
      remove(:block_number)
    end
  end
end
