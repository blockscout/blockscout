defmodule Explorer.Repo.Migrations.AddressCoinBalancesDailyAddPrimaryKey do
  use Ecto.Migration

  def change do
    alter table(:address_coin_balances_daily) do
      modify(:address_hash, :bytea, null: false, primary_key: true)
      modify(:day, :date, null: false, primary_key: true)
    end
  end
end
