defmodule Explorer.Repo.Migrations.AddFetchVoterVotesToCeloPendingEpochOperations do
  use Ecto.Migration

  def up do
    alter table(:celo_pending_epoch_operations) do
      add(:fetch_voter_votes, :boolean, default: false)
      modify(:fetch_epoch_rewards, :boolean, default: false)
      modify(:fetch_validator_group_data, :boolean, default: false)
    end
  end

  def down do
    alter table(:celo_pending_epoch_operations) do
      remove(:fetch_voter_votes, :boolean)
      modify(:fetch_epoch_rewards, :boolean)
      modify(:fetch_validator_group_data, :boolean)
    end
  end
end
