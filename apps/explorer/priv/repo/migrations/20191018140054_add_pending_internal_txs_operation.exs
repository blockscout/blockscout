defmodule Explorer.Repo.Migrations.AddPendingInternalTxsOperation do
  use Ecto.Migration

  def change do
    alter table(:pending_block_operations) do
      add(:fetch_internal_transactions, :boolean, null: false)
    end

  end
end
