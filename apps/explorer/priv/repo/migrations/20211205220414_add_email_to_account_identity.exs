defmodule Explorer.Repo.Migrations.AddEmailToAccountIdentity do
  use Ecto.Migration

  def change do
    alter table(:account_identities) do
      add(:email, :string)
    end
  end
end
