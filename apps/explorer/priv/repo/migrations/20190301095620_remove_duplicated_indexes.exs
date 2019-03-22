defmodule Explorer.Repo.Migrations.RemoveDuplicatedIndexes do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(:address_current_token_balances, [:address_hash, :block_number, :token_contract_address_hash],
        name: "address_current_token_balances_block_number_index"
      )
    )

    drop_if_exists(
      index(:internal_transactions, [:to_address_hash], name: "internal_transactions_to_address_hash_index")
    )

    drop_if_exists(
      index(:internal_transactions, [:transaction_hash], name: "internal_transactions_transaction_hash_index")
    )

    drop_if_exists(index(:logs, [:transaction_hash], name: "logs_transaction_hash_index"))
    drop_if_exists(index(:token_transfers, [:from_address_hash], name: "token_transfers_from_address_hash_index"))
    drop_if_exists(index(:token_transfers, [:to_address_hash], name: "token_transfers_to_address_hash_index"))
    drop_if_exists(index(:token_transfers, [:transaction_hash], name: "token_transfers_transaction_hash_index"))
    drop_if_exists(index(:transaction_forks, [:uncle_hash], name: "transaction_forks_uncle_hash_index"))
    drop_if_exists(index(:transactions, [:block_hash], name: "transactions_block_hash_index"))

    drop_if_exists(
      index(:transactions, [:created_contract_address_hash], name: "transactions_created_contract_address_hash_index")
    )

    drop_if_exists(index(:user_contracts, [:user_id], name: "user_contacts_user_id_index"))
  end
end
