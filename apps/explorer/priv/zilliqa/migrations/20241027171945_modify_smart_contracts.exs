defmodule Explorer.Repo.Zilliqa.Migrations.ModifySmartContracts do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      modify(:name, :string, null: true)
      modify(:compiler_version, :string, null: true)
    end
  end
end
