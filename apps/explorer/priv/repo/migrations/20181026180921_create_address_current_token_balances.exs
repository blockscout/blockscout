defmodule Explorer.Repo.Migrations.CreateAddressCurrentTokenBalances do
  use Ecto.Migration

  def change do
    create table(:address_current_token_balances) do
      add(:address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:block_number, :bigint, null: false)

      add(
        :token_contract_address_hash,
        references(:tokens, column: :contract_address_hash, type: :bytea),
        null: false
      )

      add(:value, :decimal, null: true)
      add(:value_fetched_at, :utc_datetime_usec, default: fragment("NULL"), null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:address_current_token_balances, ~w(address_hash token_contract_address_hash)a))

    create(
      index(
        :address_current_token_balances,
        [:value],
        name: :address_current_token_balances_value,
        where: "value IS NOT NULL"
      )
    )
  end
end
