defmodule Explorer.Repo.Beacon.Migrations.CreateDeposits do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE beacon_deposits_status AS ENUM ('invalid', 'pending', 'completed')",
      "DROP TYPE beacon_deposits_status"
    )

    create table(:beacon_deposits, primary_key: false) do
      add(:pubkey, :bytea, null: false)
      add(:withdrawal_credentials, :bytea, null: false)
      add(:amount, :decimal, precision: 100, scale: 0, null: false)
      add(:signature, :bytea, null: false)
      add(:index, :bigint, null: false, primary_key: true)
      add(:block_number, :bigint, null: false)
      add(:block_timestamp, :utc_datetime_usec, null: false)
      add(:log_index, :integer, null: false)
      add(:status, :beacon_deposits_status, null: false)

      add(:from_address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)

      add(:block_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: false)

      add(:transaction_hash, references(:transactions, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:beacon_deposits, [:from_address_hash]))
    create(index(:beacon_deposits, [:block_hash]))
    create(index(:beacon_deposits, [:pubkey], where: "status != 'invalid'"))

    create(
      index(:beacon_deposits, [:pubkey, :withdrawal_credentials, :amount, :signature, :block_timestamp],
        where: "status = 'pending'",
        name: :beacon_deposits_composite_key_only_pending_index
      )
    )
  end
end
