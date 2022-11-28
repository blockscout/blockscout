defmodule Explorer.Repo.Migrations.AddBlockHashToCeloEpochRewards do
  @moduledoc """
  This migration adds block_hash column to celo_election_rewards which allows to avoid expensive join with blocks table
  """
  use Ecto.Migration

  def up do
    alter table(:celo_election_rewards) do
      add(:block_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: true)
    end

    execute("""
    UPDATE celo_election_rewards r
    SET block_hash = b.hash
    FROM blocks b
    WHERE b.number = r.block_number;
    """)
  end

  def down do
    alter table(:celo_election_rewards) do
      remove(:block_hash)
    end
  end
end
