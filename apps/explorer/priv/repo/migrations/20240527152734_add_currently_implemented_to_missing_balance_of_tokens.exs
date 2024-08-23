defmodule Explorer.Repo.Migrations.AddCurrentlyImplementedToMissingBalanceOfTokens do
  use Ecto.Migration

  def change do
    alter table(:missing_balance_of_tokens) do
      add(:currently_implemented, :boolean)
    end
  end
end
