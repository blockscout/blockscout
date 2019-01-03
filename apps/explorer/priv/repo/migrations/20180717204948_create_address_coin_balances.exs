defmodule Explorer.Repo.Migrations.CreateCoinBalances do
  use Ecto.Migration

  def change do
    create table(:address_coin_balances, primary_key: false) do
      add(:address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:block_number, :bigint, null: false)

      # null until fetched
      add(:value, :numeric, precision: 100, default: fragment("NULL"), null: true)
      add(:value_fetched_at, :utc_datetime_usec, default: fragment("NULL"), null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:address_coin_balances, [:address_hash, :block_number]))

    create(
      unique_index(
        :address_coin_balances,
        [:address_hash, :block_number],
        name: :unfetched_balances,
        where: "value_fetched_at IS NULL"
      )
    )
  end
end
