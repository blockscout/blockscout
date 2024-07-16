defmodule Explorer.Repo.Migrations.LogsAscIndex do
  use Ecto.Migration

  def change do
    create(index(:logs, ["block_number ASC, index ASC"]))
  end
end
