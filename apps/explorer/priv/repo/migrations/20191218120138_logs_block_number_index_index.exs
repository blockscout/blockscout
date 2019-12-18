defmodule Explorer.Repo.Migrations.LogsBlockNumberIndexIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:logs, ["block_number DESC, index DESC"]))

    drop_if_exists(index(:logs, [:block_number], name: "logs_block_number_index"))
  end
end
