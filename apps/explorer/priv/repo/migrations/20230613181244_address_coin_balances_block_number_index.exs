defmodule Explorer.Repo.Migrations.AddressCoinBalancesBlockNumberIndex do
  use Ecto.Migration

  def up do
    create(index(:address_coin_balances, [:block_number]))
  end

  def down do
    drop(index(:address_coin_balances, [:block_number]))
  end
end
