defmodule Explorer.Repo.Migrations.DropUnusedLogsTypeIndex do
  use Ecto.Migration

  def change do
    drop(index(:logs, [:type], name: :logs_type_index))
  end
end
