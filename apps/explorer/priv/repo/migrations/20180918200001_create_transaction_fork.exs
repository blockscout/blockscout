defmodule Explorer.Repo.Migrations.CreateTransactionBlockUncles do
  use Ecto.Migration

  def change do
    create table(:transaction_forks, primary_key: false) do
      add(:hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      add(:index, :integer, null: false)
      add(:uncle_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: false)

      timestamps()
    end

    create(index(:transaction_forks, :uncle_hash))
    create(unique_index(:transaction_forks, [:uncle_hash, :index]))
  end
end
