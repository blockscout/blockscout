defmodule Explorer.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:username, :string, null: false)
      add(:password_hash, :string, null: false)

      timestamps()
    end

    create(index(:users, ["lower(username)"], unique: true, name: :unique_username))
  end
end
