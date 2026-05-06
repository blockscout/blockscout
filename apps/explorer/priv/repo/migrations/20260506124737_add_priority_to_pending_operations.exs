defmodule Explorer.Repo.Migrations.AddPriorityToPendingOperations do
  use Ecto.Migration

  def change do
    alter table(:pending_block_operations) do
      add(:priority, :smallint)
    end

    alter table(:pending_transaction_operations) do
      add(:priority, :smallint)
    end

    create(index(:pending_block_operations, :priority))
    create(index(:pending_transaction_operations, :priority))
  end
end
