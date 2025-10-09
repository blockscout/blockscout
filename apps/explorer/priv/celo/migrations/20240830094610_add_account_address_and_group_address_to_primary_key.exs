defmodule Explorer.Repo.Celo.Migrations.AddAccountAddressAndGroupAddressToPrimaryKey do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE celo_validator_group_votes
    DROP CONSTRAINT celo_validator_group_votes_pkey
    """)

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

  def down do
    execute("""
    ALTER TABLE celo_validator_group_votes
    DROP CONSTRAINT celo_validator_group_votes_pkey
    """)

    execute("""
    ALTER TABLE celo_validator_group_votes
    ADD CONSTRAINT celo_validator_group_votes_pkey
    PRIMARY KEY transaction_hash
    """)
  end
end
