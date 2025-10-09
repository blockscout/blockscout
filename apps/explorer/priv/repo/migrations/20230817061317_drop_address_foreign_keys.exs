defmodule Explorer.Repo.Migrations.DropAddressForeignKeys do
  use Ecto.Migration

  def change do
    drop_if_exists(constraint(:address_coin_balances, :address_coin_balances_address_hash_fkey))
    drop_if_exists(constraint(:address_token_balances, :address_token_balances_address_hash_fkey))
    drop_if_exists(constraint(:address_current_token_balances, :address_current_token_balances_address_hash_fkey))
    drop_if_exists(constraint(:tokens, :tokens_contract_address_hash_fkey))
    drop_if_exists(constraint(:internal_transactions, :internal_transactions_created_contract_address_hash_fkey))
    drop_if_exists(constraint(:internal_transactions, :internal_transactions_from_address_hash_fkey))
    drop_if_exists(constraint(:internal_transactions, :internal_transactions_to_address_hash_fkey))
  end
end
