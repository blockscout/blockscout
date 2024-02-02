defmodule Explorer.Repo.Migrations.ModifyAddressGasUsedBigint do
  use Ecto.Migration

  def up do
    alter table(:addresses) do
      modify(:gas_used, :bigint)
    end
  end

  def down do
    alter table(:addresses) do
      modify(:gas_used, :integer)
    end
  end
end
