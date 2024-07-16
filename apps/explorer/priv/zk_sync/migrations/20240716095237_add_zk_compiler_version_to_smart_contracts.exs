defmodule Explorer.Repo.ZkSync.Migrations.AddZkCompilerVersionToSmartContracts do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:zk_compiler_version, :string, null: false)
      modify(:optimization_runs, :string, null: true)
    end
  end
end
