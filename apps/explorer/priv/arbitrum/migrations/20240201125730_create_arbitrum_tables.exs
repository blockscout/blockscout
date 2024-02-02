defmodule Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE arbitrum_messages_op_type AS ENUM ('to_l2', 'from_l2')",
      "DROP TYPE arbitrum_messages_op_type"
    )

    execute(
      "CREATE TYPE arbitrum_messages_status AS ENUM ('initiated', 'confirmed', 'relayed')",
      "DROP TYPE arbitrum_messages_status"
    )

    create table(:arbitrum_crosslevel_messages, primary_key: false) do
      add(:direction, :arbitrum_messages_op_type, null: false, primary_key: true)
      add(:message_id, :integer, null: false, primary_key: true)
      add(:originator_address, :bytea, null: true)
      add(:originating_tx_hash, :bytea, null: true)
      add(:origination_timestamp, :"timestamp without time zone", null: true)
      add(:originating_tx_blocknum, :bigint, null: true)
      add(:completion_tx_hash, :bytea, null: true)
      add(:status, :arbitrum_messages_status, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
