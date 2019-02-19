defmodule Explorer.Repo.Migrations.AddConstructorArgumentsToSmartContracts do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE smart_contracts DROP COLUMN IF EXISTS constructor_arguments")

    alter table(:smart_contracts) do
      add(:constructor_arguments, :string, null: true)
    end
  end
end
