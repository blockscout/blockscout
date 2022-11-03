defmodule Explorer.Repo.Migrations.CreateL2SentMessageEvents do
  use Ecto.Migration

  def change do
    create table(:l2_sent_message_events, primary_key: false) do
      add(:tx_hash, :bytea, null: false)
      add(:block_number, :bigint, null: false)
      add(:target, :bytea, null: false)
      add(:sender, :bytea, null: false)
      add(:message, :bytea, null: false)
      add(:message_nonce, :bytea, null: false, primary_key: true)
      add(:gas_limit, :numeric, precision: 100, null: false)
      add(:signature, :bytea, null: false)
      add(:timestamp, :utc_datetime_usec, null: false)
      add(:is_merge, :boolean, null: false, default: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
