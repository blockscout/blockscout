defmodule Explorer.Repo.Migrations.CreateAddressTransactionsCounter do
  use Ecto.Migration

  def change do
    create table(:address_transaction_counter, primary_key: true) do
      add(
        :address_hash,
        references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      add(:transactions_number, :bigint, default: 0)
    end
  end
end
