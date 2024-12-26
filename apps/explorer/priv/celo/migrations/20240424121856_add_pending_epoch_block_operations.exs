defmodule Explorer.Repo.Celo.Migrations.AddPendingEpochBlockOperations do
  use Ecto.Migration

  def change do
    create table(:celo_pending_epoch_block_operations, primary_key: false) do
      add(:block_hash, references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      timestamps()
    end
  end
end
