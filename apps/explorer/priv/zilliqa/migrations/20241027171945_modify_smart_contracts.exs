defmodule Explorer.Repo.Zilliqa.Migrations.ModifySmartContracts do
  use Ecto.Migration

  def up do
    alter table(:smart_contracts) do
      modify(:name, :string, null: true)
      modify(:compiler_version, :string, null: true)
    end
  end

  def down do
    alter table(:smart_contracts) do
      modify(:name, :string, null: false)
      modify(:compiler_version, :string, null: false)
    end
  end
end
