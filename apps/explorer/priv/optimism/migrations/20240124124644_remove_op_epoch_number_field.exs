defmodule Explorer.Repo.Migrations.RemoveOpEpochNumberField do
  use Ecto.Migration

  def change do
    alter table(:op_transaction_batches) do
      remove(:epoch_number)
    end
  end
end
