defmodule Explorer.Repo.Migrations.CreateAdministrators do
  use Ecto.Migration

  def change do
    create table(:administrators) do
      add(:role, :string, null: false)
      add(:user_id, references(:users, column: :id, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(unique_index(:administrators, :role, name: :owner_role_limit, where: "role = 'owner'"))
    create(unique_index(:administrators, :user_id))
  end
end
