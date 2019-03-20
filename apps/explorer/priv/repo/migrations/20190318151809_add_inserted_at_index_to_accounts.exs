defmodule Explorer.Repo.Migrations.AddInsertedAtIndexToAccounts do
  use Ecto.Migration

  def change do
    create(index(:addresses, :inserted_at))
  end
end
