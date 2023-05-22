defmodule Explorer.Repo.Migrations.AddBlockNumberToPendingBlockOperations do
  use Ecto.Migration

  def change do
    alter table(:pending_block_operations) do
      add(:block_number, :integer)
    end
  end
end
