defmodule Explorer.Repo.Optimism.Migrations.OPWithdrawalEventsKey do
  use Ecto.Migration

  def up do
    execute("TRUNCATE TABLE op_withdrawal_events;")

    drop(constraint("op_withdrawal_events", "op_withdrawal_events_pkey"))

    alter table(:op_withdrawal_events) do
      modify(:withdrawal_hash, :bytea, primary_key: true)
      modify(:l1_event_type, :withdrawal_event_type, primary_key: true)
      modify(:l1_transaction_hash, :bytea, primary_key: true)
    end
  end

  def down do
    execute("TRUNCATE TABLE op_withdrawal_events;")

    drop(constraint("op_withdrawal_events", "op_withdrawal_events_pkey"))

    alter table(:op_withdrawal_events) do
      modify(:withdrawal_hash, :bytea, primary_key: true)
      modify(:l1_event_type, :withdrawal_event_type, primary_key: true)
    end
  end
end
