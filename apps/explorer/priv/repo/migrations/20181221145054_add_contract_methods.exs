defmodule Explorer.Repo.Migrations.AddContractMethods do
  use Ecto.Migration

  def change do
    create table(:contract_methods) do
      add(:identifier, :integer, null: false)
      add(:abi, :map, null: false)
      add(:type, :string, null: false)

      timestamps()
    end

    create(unique_index(:contract_methods, [:identifier, :abi]))
  end
end
