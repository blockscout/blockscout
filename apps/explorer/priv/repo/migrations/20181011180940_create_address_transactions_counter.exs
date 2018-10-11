defmodule Explorer.Repo.Migrations.CreateAddressTransactionsCounter do
  use Ecto.Migration

  def change do
    create table(:address_transaction_counter, primary_key: false) do
      add(
        :address_hash,
        references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false,
        primary_key: true
      )

      add(:transactions_number, :bigint, default: 0)
    end
  end
end
