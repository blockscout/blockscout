defmodule Explorer.Repo.Migrations.AddDeltaToCoinbalance do
  use Ecto.Migration

  def change do
    alter table(:address_coin_balances) do
      add(:delta, :numeric, precision: 100, default: nil, null: true)
      add(:delta_updated_at, :utc_datetime_usec, default: nil, null: true)
    end
  end
end
