defmodule Explorer.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string
      add :password_hash, :string

      timestamps()
    end

    create index(:users, ["lower(username)"], unique: true, name: :unique_username)
  end
end
