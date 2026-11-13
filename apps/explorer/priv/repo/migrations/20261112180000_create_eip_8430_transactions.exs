# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.CreateEip8430Transactions do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE eip_8430_payer_type AS ENUM ('self', 'open', 'named', 'unknown')",
      "DROP TYPE eip_8430_payer_type"
    )

    create table(:eip_8430_transactions, primary_key: false) do
      add(:transaction_hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false,
        primary_key: true
      )

      add(:has_named_sender, :boolean, null: false)
      add(:nonce_key, :numeric, precision: 78, scale: 0, null: false)
      add(:valid_after, :numeric, precision: 20, scale: 0, null: false)
      add(:valid_before, :numeric, precision: 20, scale: 0, null: false)
      add(:metadata, :bytea, null: true)
      add(:payer_type, :eip_8430_payer_type, null: false)
      add(:payer, :bytea, null: true)
      add(:sender_auth, :bytea, null: true)
      add(:payer_auth, :bytea, null: true)
      add(:account_changes, :jsonb, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
