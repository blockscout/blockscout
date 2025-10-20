defmodule Explorer.Repo.Celo.Migrations.AddLogIndexToValidatorGroupVotes do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE celo_validator_group_votes
    DROP CONSTRAINT celo_validator_group_votes_pkey
    """)

    alter table(:celo_validator_group_votes) do
      add(:log_index, :integer, null: false, default: 0)
    end

    execute("""
    ALTER TABLE celo_validator_group_votes
    ADD CONSTRAINT celo_validator_group_votes_pkey
    PRIMARY KEY (
      transaction_hash,
      log_index,
      account_address_hash,
      group_address_hash
    )
    """)
  end

  def down do
    execute("""
    ALTER TABLE celo_validator_group_votes
    DROP CONSTRAINT celo_validator_group_votes_pkey
    """)

    alter table(:celo_validator_group_votes) do
      remove(:log_index)
    end

    execute("""
    ALTER TABLE celo_validator_group_votes
    ADD CONSTRAINT celo_validator_group_votes_pkey
    PRIMARY KEY (
      transaction_hash,
      account_address_hash,
      group_address_hash
    )
    """)
  end
end
