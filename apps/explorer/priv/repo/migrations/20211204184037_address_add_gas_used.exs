defmodule Explorer.Repo.Migrations.AddressAddGasUsed do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add(:gas_used, :integer, null: true)
    end
  end
end
