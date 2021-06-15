defmodule Explorer.Repo.Migrations.CreateTokenTransfersTokenContractAddressHashTokenIdBlockNumberIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:token_transfers, [:token_contract_address_hash, "token_id DESC", "block_number DESC"]))
  end
end
