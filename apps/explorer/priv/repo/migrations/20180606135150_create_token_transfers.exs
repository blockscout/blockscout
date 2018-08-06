defmodule Explorer.Repo.Migrations.CreateTokenTransfers do
  use Ecto.Migration

  def change do
    create table(:token_transfers) do
      add(
        :transaction_hash,
        references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      add(:log_index, :integer, null: false)
      add(:from_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:to_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      # Some token transfers do not have a fungible value like ERC721 transfers
      add(:amount, :decimal, null: true)
      # ERC-721 tokens have IDs
      add(:token_id, :integer, null: true)
      add(:token_contract_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)

      timestamps()
    end

    create(index(:token_transfers, :transaction_hash))
    create(index(:token_transfers, :to_address_hash))
    create(index(:token_transfers, :from_address_hash))
    create(index(:token_transfers, :token_contract_address_hash))

    create(unique_index(:token_transfers, [:transaction_hash, :log_index]))
  end
end
