defmodule Explorer.Repo.Migrations.AddReceiptIdToTransactions do
  use Ecto.Migration

  def change do
    alter table("transactions") do
      add :receipt_id, :bigint
    end
  end
end
