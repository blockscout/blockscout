defmodule Explorer.Repo.Migrations.ChangeConstructorArgumentsToText do
  use Ecto.Migration

  def up do
    alter table(:smart_contracts) do
      modify(:constructor_arguments, :text)
    end
  end

  def down do
    alter table(:smart_contracts) do
      modify(:constructor_arguments, :string)
    end
  end
end
