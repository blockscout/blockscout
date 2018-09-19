defmodule Explorer.Repo.Migrations.AlterTokenDecimalsToBigint do
  use Ecto.Migration

  def up do
    alter table("tokens") do
      modify(:decimals, :bigint)
    end
  end

  def down do
    alter table("tokens") do
      modify(:decimals, :smallint)
    end
  end
end
