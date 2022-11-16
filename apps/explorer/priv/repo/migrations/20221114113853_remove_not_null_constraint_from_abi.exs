defmodule Explorer.Repo.Migrations.RemoveNotNullConstraintFromAbi do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE smart_contracts ALTER COLUMN abi DROP NOT NULL;")
  end
end
