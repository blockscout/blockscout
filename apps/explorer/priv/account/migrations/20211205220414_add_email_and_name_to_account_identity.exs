defmodule Explorer.Repo.Account.Migrations.AddEmailToAccountIdentity do
  use Ecto.Migration

  def change do
    alter table(:account_identities) do
      add(:email, :string)
      add(:name, :string)
    end
  end
end
