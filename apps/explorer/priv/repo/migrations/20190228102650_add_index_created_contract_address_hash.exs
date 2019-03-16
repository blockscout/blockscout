defmodule Explorer.Repo.Migrations.AddIndexCreatedContractAddressHas do
  use Ecto.Migration

  def change do
    create(index(:transactions, [:created_contract_address_hash]))
  end
end
