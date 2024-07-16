defmodule Explorer.Repo.Migrations.ConstrainNullDateMarketHistory do
  use Ecto.Migration

  def change do
    alter table(:market_history) do
      modify(:date, :date, null: false, from: {:date, null: true})
    end
  end
end
