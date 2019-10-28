defmodule Explorer.Repo.Migrations.AddBlockHashToPrimaryKey do
  use Ecto.Migration

  def change do
    drop(constraint(:internal_transactions, "internal_transactions_pkey"))

    alter table(:internal_transactions) do
      modify(:transaction_hash, :bytea, primary_key: true)
      modify(:block_hash, :bytea, primary_key: true)
      modify(:index, :integer, primary_key: true)
    end
  end
end
