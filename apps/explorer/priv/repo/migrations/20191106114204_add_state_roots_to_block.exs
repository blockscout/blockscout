defmodule Explorer.Repo.Migrations.AddStateRootsToBlock do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      add(:transactions_root, :bytea, null: true)
      add(:state_root, :bytea, null: true)
      add(:receipts_root, :bytea, null: true)
    end
  end
end
