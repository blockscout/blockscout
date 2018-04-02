defmodule Explorer.Repo.Migrations.CreateAddress do
  use Ecto.Migration

  def change do
    create table(:addresses) do
      add :balance, :numeric, precision: 100
      add :balance_updated_at, :utc_datetime
      add :hash, :string, null: false

      timestamps null: false
    end

    create unique_index(:addresses, [:hash])
  end
end
