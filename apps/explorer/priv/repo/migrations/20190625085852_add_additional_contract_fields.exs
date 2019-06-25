defmodule Explorer.Repo.Migrations.AddAdditionalContractFields do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:optimization_runs, :integer, null: true)
      add(:evm_version, :string, null: true)
      add(:external_libraries, :jsonb, null: true)
    end
  end
end
