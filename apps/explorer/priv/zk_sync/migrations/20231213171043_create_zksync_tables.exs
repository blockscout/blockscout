defmodule Explorer.Repo.ZkSync.Migrations.CreateZkSyncTables do
  use Ecto.Migration

  def change do
    create table(:zksync_lifecycle_l1_transactions, primary_key: false) do
      add(:id, :integer, null: false, primary_key: true)
      add(:hash, :bytea, null: false)
      add(:timestamp, :"timestamp without time zone", null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:zksync_lifecycle_l1_transactions, :hash))
  end
end
