defmodule Explorer.Repo.Migrations.AddOldValueForCurrentTokenBalances do
  use Ecto.Migration

  def change do
    alter table(:address_current_token_balances) do
      # A transient field for deriving token holder count deltas during address_current_token_balances upserts
      add(:old_value, :decimal, null: true)
    end
  end
end
