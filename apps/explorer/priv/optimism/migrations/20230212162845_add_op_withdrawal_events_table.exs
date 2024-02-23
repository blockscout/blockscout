defmodule Explorer.Repo.Migrations.AddOpWithdrawalEventsTable do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE withdrawal_event_type AS ENUM ('WithdrawalProven', 'WithdrawalFinalized')",
      "DROP TYPE withdrawal_event_type"
    )

    create table(:op_withdrawal_events, primary_key: false) do
      add(:withdrawal_hash, :bytea, null: false, primary_key: true)
      add(:l1_event_type, :withdrawal_event_type, null: false, primary_key: true)
      add(:l1_timestamp, :"timestamp without time zone", null: false)
      add(:l1_tx_hash, :bytea, null: false)
      add(:l1_block_number, :bigint, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:op_withdrawal_events, :l1_timestamp))
  end
end
