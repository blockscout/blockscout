defmodule Explorer.Repo.Migrations.AddConstructorArgumentsToSmartContracts do
  use Ecto.Migration

  def up do
    # Check for the existence of constructor arguments and remove
    execute("ALTER TABLE smart_contracts DROP COLUMN IF EXISTS constructor_arguments")
  end

  def down do
    alter table(:smart_contracts) do
      add(:constructor_arguments, :string, null: true)
    end
  end
end
