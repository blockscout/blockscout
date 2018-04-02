defmodule Explorer.Repo.Migrations.AddBalanceAndBalanceUpdatedAtToAddress do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add :balance, :numeric, precision: 100
      add :balance_updated_at, :utc_datetime
    end
  end
end
