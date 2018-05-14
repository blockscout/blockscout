defmodule Explorer.Repo.Migrations.CreateUserContacts do
  use Ecto.Migration

  def change do
    create table(:user_contacts) do
      add(:email, :string, null: false)
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:primary, :boolean, default: false)
      add(:verified, :boolean, default: false)

      timestamps()
    end

    create(index(:user_contacts, :user_id))

    # No duplicate email addresses per user
    create(unique_index(:user_contacts, [:user_id, "lower(email)"], name: :email_unique_for_user))

    # One primary contact per user
    create(index(:user_contacts, [:user_id], unique: true, where: ~s("primary"), name: :one_primary_per_user))
  end
end
