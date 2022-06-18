defmodule Explorer.Repo.Migrations.AddAccountIdentityFields do
  use Ecto.Migration

  def change do
    alter table("account_identities") do
      add(:nickname, :string, null: true)
      add(:avatar, :text, null: true)
    end
  end
end
