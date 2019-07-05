defmodule Explorer.Repo.Migrations.AddTxHashInsertedAtIndex do
  use Ecto.Migration

  def change do
    create(index(:transactions, [:hash, :inserted_at]))
  end
end
