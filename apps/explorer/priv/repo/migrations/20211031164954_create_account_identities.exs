defmodule Explorer.Repo.Migrations.CreateAccountIdentities do
  use Ecto.Migration

  def change do
    create table(:account_identities) do
      add(:uid, :string)

      timestamps()
    end

    create(unique_index(:account_identities, [:uid]))
  end
end
