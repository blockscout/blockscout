defmodule Explorer.Repo.Account.Migrations.AddNicknameToIdentities do
  use Ecto.Migration

  def change do
    alter table(:account_identities) do
      add :nickname, :string
    end

    create unique_index(:account_identities, [:nickname])
  end
end
