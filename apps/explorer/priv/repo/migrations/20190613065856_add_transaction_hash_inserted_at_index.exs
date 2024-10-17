defmodule Explorer.Repo.Migrations.AddTransactionHashInsertedAtIndex do
  use Ecto.Migration

  def change do
    create(index(:transactions, [:hash, :inserted_at]))
  end
end
