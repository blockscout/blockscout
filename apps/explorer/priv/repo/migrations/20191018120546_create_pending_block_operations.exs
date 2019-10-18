defmodule Explorer.Repo.Migrations.CreatePendingBlockOperations do
  use Ecto.Migration

  def change do
    create table(:pending_block_operations, primary_key: false) do
      add(:block_hash, references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
