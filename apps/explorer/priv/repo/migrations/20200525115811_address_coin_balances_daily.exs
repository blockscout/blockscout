defmodule Explorer.Repo.Migrations.AddressCoinBalancesDaily do
  use Ecto.Migration

  def change do
    create table(:address_coin_balances_daily, primary_key: false) do
      add(:address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:day, :date, null: false)

      # null until fetched
      add(:value, :numeric, precision: 100, default: fragment("NULL"), null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:address_coin_balances_daily, [:address_hash, :day]))
  end
end
