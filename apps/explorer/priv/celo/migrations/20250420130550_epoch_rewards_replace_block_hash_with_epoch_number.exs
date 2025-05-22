defmodule Explorer.Repo.Celo.Migrations.EpochRewardsReplaceBlockHashWithEpochNumber do
  use Ecto.Migration

  def change do
    alter table(:celo_epoch_rewards) do
      add(:epoch_number, references(:celo_epochs, column: :number, on_delete: :delete_all))
    end

    execute("""
    UPDATE celo_epoch_rewards er
    SET epoch_number = e.number
    FROM celo_epochs e
    WHERE er.block_hash = e.end_processing_block_hash
    """)

    execute("""
    ALTER TABLE celo_epoch_rewards DROP CONSTRAINT celo_epoch_rewards_pkey;
    """)

    execute("""
    ALTER TABLE celo_epoch_rewards ADD PRIMARY KEY (epoch_number);
    """)

    # Drop the block_hash column
    alter table(:celo_epoch_rewards) do
      remove(:block_hash)
    end
  end
end
