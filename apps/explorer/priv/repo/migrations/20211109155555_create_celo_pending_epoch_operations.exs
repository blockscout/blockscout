defmodule Explorer.Repo.Migrations.CreateCeloPendingEpochOperations do
  use Ecto.Migration

  def change do
    create table(:celo_pending_epoch_operations, primary_key: false) do
      add(:block_hash, references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      add(:fetch_epoch_rewards, :boolean, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
