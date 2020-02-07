defmodule Explorer.Repo.Migrations.LogsBlockNumberIndexIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:logs, ["block_number DESC, index DESC"]))
  end
end
