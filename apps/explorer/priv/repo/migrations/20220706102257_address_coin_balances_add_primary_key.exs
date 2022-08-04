defmodule Explorer.Repo.Migrations.AddressCoinBalancesAddPrimaryKey do
  use Ecto.Migration

  def change do
    drop(
      unique_index(
        :address_coin_balances,
        ~w(address_hash block_number)a
      )
    )

    alter table(:address_coin_balances) do
      modify(:address_hash, :bytea, null: false, primary_key: true)
      modify(:block_number, :bigint, null: false, primary_key: true)
    end
  end
end
