defmodule Explorer.Repo.Migrations.MigrateOptimizationRunsToInt8 do
  use Ecto.Migration

  def up do
    alter table(:smart_contracts) do
      modify(:optimization_runs, :bigint)
    end
  end

  def down do
    alter table(:smart_contracts) do
      modify(:optimization_runs, :integer)
    end
  end
end
