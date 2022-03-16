defmodule Explorer.Repo.Migrations.AddConsensusToTransactionTable do
  use Ecto.Migration

  def change do
    alter table("transactions") do
      add(:block_consensus, :boolean, default: true)
    end

    execute("""
    UPDATE transactions tx
    SET block_consensus = b.consensus
    FROM blocks b
    WHERE b.hash = tx.block_hash;
    """)

    create(index(:transactions, :block_consensus))
  end
end
