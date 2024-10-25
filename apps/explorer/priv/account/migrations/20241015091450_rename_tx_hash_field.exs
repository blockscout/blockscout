defmodule Explorer.Repo.Account.Migrations.RenameTxHashField do
  use Ecto.Migration

  def change do
    rename(table(:account_tag_transactions), :tx_hash, to: :transaction_hash)
    rename(table(:account_tag_transactions), :tx_hash_hash, to: :transaction_hash_hash)
    rename(table(:account_watchlist_notifications), :tx_fee, to: :transaction_fee)
  end
end
