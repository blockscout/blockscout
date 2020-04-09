defmodule Explorer.Repo.Migrations.CreateTransactionStats do
  use Ecto.Migration

  def change do
    create table(:transaction_stats) do
      add(:date, :date)
      add(:number_of_transactions, :integer)
    end

    create(unique_index(:transaction_stats, :date))
  end
end
