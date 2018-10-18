defmodule Explorer.Repo.Migrations.ModifyUsersUsername do
  use Ecto.Migration

  def up do
    drop(index(:users, ["lower(username)"], unique: true, name: :unique_username))

    alter table(:users) do
      modify(:username, :citext)
    end

    create(unique_index(:users, [:username], name: :unique_username))
  end

  def down do
    drop(unique_index(:users, [:username], name: :unique_username))

    alter table(:users) do
      modify(:username, :string)
    end

    create(index(:users, ["lower(username)"], unique: true, name: :unique_username))
  end
end
