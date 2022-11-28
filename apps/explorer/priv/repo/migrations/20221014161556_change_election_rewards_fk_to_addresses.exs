defmodule Explorer.Repo.Migrations.ChangeElectionRewardsFkToAddresses do
  use Ecto.Migration

  def up do
    drop(constraint(:celo_election_rewards, "celo_election_rewards_associated_account_hash_fkey"))

    alter table(:celo_election_rewards) do
      modify(:associated_account_hash, references(:addresses, column: :hash, type: :bytea))
    end
  end

  def down do
    drop(constraint(:celo_election_rewards, "celo_election_rewards_associated_account_hash_fkey"))

    alter table(:celo_election_rewards) do
      modify(:associated_account_hash, references(:celo_account, column: :address, type: :bytea))
    end
  end
end
