defmodule Explorer.Repo.Migrations.AddTransactionIndexToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:transaction_index, :integer)
    end
  end
end
