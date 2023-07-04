defmodule Explorer.Repo.Migrations.AddNearData do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:near_receipt_hash, :string, null: true)
      add(:near_transaction_hash, :string, null: true)
    end
  end
end
