defmodule Explorer.Repo.Migrations.AddressCoinBalancesAddPrimaryKey do
  use Ecto.Migration

  def change do
    alter table(:address_coin_balances) do
      modify(:address_hash, :bytea, null: false, primary_key: true)
      modify(:block_number, :bigint, null: false, primary_key: true)
    end
  end
end
