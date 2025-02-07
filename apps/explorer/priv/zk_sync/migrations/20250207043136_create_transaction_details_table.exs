defmodule Explorer.Repo.ZkSync.Migrations.CreateTransactionDetailsTable do
  use Ecto.Migration

  execute(
      "CREATE TYPE zksync_transaction_status AS ENUM ('pending', 'included', 'verifyed', 'failed')"
    )

  def change do
    create table(:zksync_transaction_details, primary_key: false) do
      add(:hash, :bytea, null: false, primary_key: true)
      #add(:received_at, :"timestamp without time zone", null: false)
      #add(:is_l1_originated, :boolean, null: false, default: false)
      #add(:status, :zksync_transaction_status, null: fale)
      #add(:gas_per_pubdata, :numeric, precision: 100, null: false)
      #add(:fee, :numeric, precision: 100, null: false)
      #timestamps(null: false, type: :utc_datetime_usec)
    end

  end
end
