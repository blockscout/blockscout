defmodule Explorer.Repo.Migrations.AddTokenTransfersTokenContractAddressTokenIdsIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create(
      index(
        :token_transfers,
        [:token_contract_address_hash, :token_ids],
        name: "token_transfers_token_contract_address_hash_token_ids_index",
        using: "GIN",
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(
      index(:token_transfers, [:token_contract_address_hash, :token_ids],
        name: :token_transfers_token_contract_address_hash_token_ids_index
      ),
      concurrently: true
    )
  end
end
