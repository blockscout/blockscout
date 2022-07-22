defmodule Explorer.Repo.Migrations.TransactionsForksAddPrimaryKey do
  use Ecto.Migration

  def change do
    drop(
      unique_index(
        :transaction_forks,
        ~w(uncle_hash index)a
      )
    )

    alter table(:transaction_forks) do
      modify(:uncle_hash, :bytea, null: false, primary_key: true)
      modify(:index, :integer, null: false, primary_key: true)
    end
  end
end
