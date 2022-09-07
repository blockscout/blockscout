defmodule Explorer.Repo.Migrations.RemoveBridgedTokens do
  use Ecto.Migration

  def change do
    drop_if_exists(table(:bridged_tokens))

    alter table(:tokens) do
      remove(:bridged)
    end
  end
end
