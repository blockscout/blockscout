defmodule Explorer.Repo.Optimism.Migrations.OPWithdrawalEventsKey do
  use Ecto.Migration

  def change do
  	drop table(:op_withdrawal_events)

    create table(:op_withdrawal_events, primary_key: false) do
      add(:withdrawal_hash, :bytea, null: false, primary_key: true)
      add(:l1_event_type, :withdrawal_event_type, null: false, primary_key: true)
      add(:l1_timestamp, :"timestamp without time zone", null: false)
      add(:l1_transaction_hash, :bytea, null: false, primary_key: true)
      add(:l1_block_number, :bigint, null: false)
      add(:game_index, :integer, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:op_withdrawal_events, :l1_timestamp))
    create(index(:op_withdrawal_events, :l1_block_number))
  end
end
