defmodule Explorer.Repo.Migrations.CreateIndexTokenTransfersTokenContractAddressHashBlockNumber do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:token_transfers, [:token_contract_address_hash, :block_number]))
  end
end
