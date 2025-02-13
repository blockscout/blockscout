defmodule Explorer.Repo.ZkSync.Migrations.CreateTransactionDetailsTable do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE zksync_transaction_status AS ENUM ('pending', 'included', 'verifyed', 'failed')")

    create table(:zksync_transaction_details, primary_key: false) do
      add(:hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      add(:received_at, :"timestamp without time zone", null: false)
      add(:is_l1_originated, :boolean, null: false, default: false)
      add(:gas_per_pubdata, :numeric, precision: 100, null: false)
      add(:fee, :numeric, precision: 100, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
