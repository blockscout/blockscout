defmodule Explorer.Repo.Migrations.TrackedEventsSchema do
  use Ecto.Migration

  def change do
    create table(:clabs_contract_event_trackings) do
      add(:smart_contract_id, references(:smart_contracts), null: false)

      add(:abi, :jsonb, null: false)
      add(:topic, :string, null: false)
      add(:name, :string, null: false)

      add(:backfilled, :boolean, null: false, default: false)
      add(:enabled, :boolean, null: false, default: true)

      timestamps()
    end

    create(index(:clabs_contract_event_trackings, :topic))
    create(index(:clabs_contract_event_trackings, :backfilled))
    create(index(:clabs_contract_event_trackings, :smart_contract_id))

    create table(:clabs_tracked_contract_events, primary_key: false) do
      add(:block_number, :integer, primary_key: true, null: false)
      add(:log_index, :integer, primary_key: true, null: false)

      add(:contract_event_tracking_id, references(:clabs_contract_event_trackings), null: false)
      add(:contract_address_hash, references(:smart_contracts, column: :address_hash, type: :bytea), null: false)

      # epoch events may have null transaction hash
      add(:transaction_hash, references(:transactions, column: :hash, type: :bytea), null: true)

      add(:topic, :string, null: false)
      add(:name, :string, null: false)
      add(:params, :jsonb)

      add(:bq_rep_id, :bigserial)

      timestamps()
    end

    create(index(:clabs_tracked_contract_events, :block_number))
    create(index(:clabs_tracked_contract_events, :transaction_hash))
    create(index(:clabs_tracked_contract_events, :updated_at))
    create(index(:clabs_tracked_contract_events, :contract_address_hash))
    create(index(:clabs_tracked_contract_events, :contract_event_tracking_id))
  end
end
