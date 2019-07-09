defmodule Explorer.Repo.Migrations.AddExternalLibrariesToSmartContracts do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      remove(:external_libraries)
    end

    alter table(:smart_contracts) do
      add(:external_libraries, {:array, :map}, default: [])
    end
  end
end
