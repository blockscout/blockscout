defmodule Explorer.Repo.Migrations.AddFiatValueForTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:fiat_value, :decimal)
    end
  end
end
