defmodule Explorer.Repo.Migrations.AddressCoinBalancesDailyAddPrimaryKey do
  use Ecto.Migration

  def change do
    drop(
      unique_index(
        :address_coin_balances_daily,
        ~w(address_hash day)a
      )
    )

    alter table(:address_coin_balances_daily) do
      modify(:address_hash, :bytea, null: false, primary_key: true)
      modify(:day, :date, null: false, primary_key: true)
    end
  end
end
