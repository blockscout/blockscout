defmodule Explorer.Repo.Migrations.CreateIndexesTokenInstancesTokenContractAddressHashTokenId do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:token_instances, [:token_contract_address_hash, :token_id]))
    create_if_not_exists(index(:token_instances, [:token_id]))
  end
end
