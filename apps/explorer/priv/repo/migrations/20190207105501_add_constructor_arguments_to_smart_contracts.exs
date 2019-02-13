defmodule Explorer.Repo.Migrations.AddConstructorArgumentsToSmartContracts do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:constructor_arguments, :string, null: true)
    end
  end
end
