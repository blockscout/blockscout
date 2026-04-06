defmodule Explorer.Repo.Migrations.UpdateObanToV13 do
  use Ecto.Migration

  def up, do: Oban.Migrations.up(version: 13)

  def down, do: Oban.Migrations.down(version: 13)
end
