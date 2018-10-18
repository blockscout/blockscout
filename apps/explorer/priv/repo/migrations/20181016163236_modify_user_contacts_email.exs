defmodule Explorer.Repo.Migrations.ModifyUserContactsEmail do
  use Ecto.Migration

  def up do
    drop(unique_index(:user_contacts, [:user_id, "lower(email)"], name: :email_unique_for_user))

    alter table(:user_contacts) do
      modify(:email, :citext)
    end

    create(unique_index(:user_contacts, [:user_id, :email], name: :email_unique_for_user))
  end

  def down do
    drop(unique_index(:user_contacts, [:user_id, :email], name: :email_unique_for_user))

    alter table(:user_contacts) do
      modify(:email, :string)
    end

    drop(unique_index(:user_contacts, [:user_id, "lower(email)"], name: :email_unique_for_user))
  end
end
