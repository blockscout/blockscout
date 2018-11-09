defmodule Explorer.Repo.Migrations.AddFieldsToInternalTransactions do
  use Ecto.Migration

  def up do
    alter table("internal_transactions") do
      add(:block_number, :integer)
      add(:transaction_index, :integer)
    end
  end

  def down do
    alter table("internal_transactions") do
      remove(:block_number)
      remove(:transaction_index)
    end
  end
end
