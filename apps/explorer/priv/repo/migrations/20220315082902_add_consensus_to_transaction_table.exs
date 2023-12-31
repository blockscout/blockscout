defmodule Explorer.Repo.Migrations.AddConsensusToTransactionTable do
  use Ecto.Migration

  def change do
    alter table("transactions") do
      add(:block_consensus, :boolean, default: true)
    end

    create(index(:transactions, :block_consensus))
  end
end
