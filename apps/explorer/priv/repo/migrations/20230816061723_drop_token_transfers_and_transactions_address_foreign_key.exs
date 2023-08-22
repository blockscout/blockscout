# cspell:ignore fkey
defmodule Explorer.Repo.Migrations.DropTokenTransfersAndTransactionsAddressForeignKey do
  use Ecto.Migration

  def change do
    drop_if_exists(constraint(:token_transfers, :token_transfers_from_address_hash_fkey))
    drop_if_exists(constraint(:token_transfers, :token_transfers_to_address_hash_fkey))
    drop_if_exists(constraint(:token_transfers, :token_transfers_token_contract_address_hash_fkey))
    drop_if_exists(constraint(:transactions, :transactions_created_contract_address_hash_fkey))
    drop_if_exists(constraint(:transactions, :transactions_from_address_hash_fkey))
    drop_if_exists(constraint(:transactions, :transactions_to_address_hash_fkey))
  end
end
