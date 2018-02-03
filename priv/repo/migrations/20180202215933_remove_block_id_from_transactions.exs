defmodule Explorer.Repo.Migrations.RemoveBlockIdFromTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      remove :block_id
    end
  end
end
