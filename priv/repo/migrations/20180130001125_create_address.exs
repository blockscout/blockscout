defmodule Explorer.Repo.Migrations.CreateAddress do
  use Ecto.Migration

  def change do
    create table(:addresses) do
      add :hash, :string, null: false
      timestamps null: false
    end

    create unique_index(:addresses, ["(lower(hash))"], name: :addresses_hash_index)
  end
end
