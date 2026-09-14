defmodule Explorer.Repo.Migrations.AddTransactionHashToTokenUiMultiplierChanges do
  use Ecto.Migration

  def change do
    alter table(:token_ui_multiplier_changes) do
      add(:transaction_hash, :bytea, null: true)
    end
  end
end
