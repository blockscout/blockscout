defmodule Explorer.Repo.Migrations.CreateAccountWatchlists do
  use Ecto.Migration

  def change do
    create table(:account_watchlists) do
      add(:name, :string, default: "default")
      add(:identity_id, references(:account_identities, on_delete: :delete_all))

      timestamps()
    end

    create(index(:account_watchlists, [:identity_id]))
  end
end
