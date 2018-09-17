defmodule Explorer.Repo.Migrations.ModifyBlockGas do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      modify(:gas_used, :numeric, precision: 100)
      modify(:gas_limit, :numeric, precision: 100)
    end
  end
end
