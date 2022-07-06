defmodule Explorer.Repo.Migrations.TransactionsForksAddPrimaryKey do
  use Ecto.Migration

  def change do
    alter table(:transaction_forks) do
      modify(:index, :integer, null: false, primary_key: true)
      modify(:uncle_hash, :bytea, null: false, primary_key: true)
    end
  end
end
