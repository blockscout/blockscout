defmodule Explorer.Repo.Migrations.CreateTokenTransfers do
  use Ecto.Migration

  def change do
    create table(:token_transfers) do
      add(
        :transaction_hash,
        references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      add(:log_id, references(:logs, on_delete: :delete_all), null: false)
      add(:from_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:to_address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:amount, :decimal, null: false)
      add(:token_id, references(:tokens), null: false)
    end

    create(unique_index(:token_transfers, :log_id))
    create(index(:token_transfers, :transaction_hash))
    create(index(:token_transfers, :to_address_hash))
    create(index(:token_transfers, :from_address_hash))
    create(index(:token_transfers, :token_id))
  end
end
