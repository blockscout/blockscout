defmodule Explorer.Repo.Account.Migrations.RemoveGuardianTokens do
  use Ecto.Migration

  def change do
    drop_if_exists(table("guardian_tokens"))
  end
end
