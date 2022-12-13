defmodule Explorer.Repo.Local.Migrations.AddFlyPostgresProc do
  use Ecto.Migration

  def up do
    Fly.Postgres.Migrations.V01.up()
  end

  def down do
    Fly.Postgres.Migrations.V01.down()
  end
end
