defmodule Explorer.Repo.Migrations.ElectionRewardsReplaceBlockHashWithEpochNumber do
  use Ecto.Migration

  def change do
    alter table(:celo_election_rewards) do
      add(
        :epoch_number,
        references(
          :celo_epochs,
          column: :number,
          on_delete: :delete_all
        )
      )
    end

    execute("""
    UPDATE celo_election_rewards er
    SET epoch_number = e.number
    FROM celo_epochs e
    WHERE er.block_hash = e.end_processing_block_hash
    """)

    execute("""
    ALTER TABLE celo_election_rewards DROP CONSTRAINT celo_election_rewards_pkey;
    """)

    execute("""
    ALTER TABLE celo_election_rewards
    ADD PRIMARY KEY (type, epoch_number, account_address_hash, associated_account_address_hash);
    """)

    alter table(:celo_election_rewards) do
      remove(:block_hash)
    end
  end
end
