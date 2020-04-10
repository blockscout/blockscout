defmodule Explorer.Repo.Migrations.CreateIndexTokenInstancesTokenContractAddressHashToken do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:token_instances, [:token_contract_address_hash, :token_id]))
  end
end
