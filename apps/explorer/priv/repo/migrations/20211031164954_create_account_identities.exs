defmodule Explorer.Repo.Migrations.CreateAccountIdentities do
  use Ecto.Migration

  def change do
    create table(:account_identities) do
      add(:uid, :string)

      timestamps()
    end
  end
end
