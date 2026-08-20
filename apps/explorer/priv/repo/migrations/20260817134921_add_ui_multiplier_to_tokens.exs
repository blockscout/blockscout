defmodule Explorer.Repo.Migrations.AddUiMultiplierToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:ui_multiplier, :decimal, null: true)
      add(:new_ui_multiplier, :decimal, null: true)
      add(:ui_multiplier_effective_at, :utc_datetime_usec, null: true)
    end
  end
end
