defmodule Explorer.Repo.Migrations.AddIndexOnBlockNumberToAddressTokenBalances do
  use Ecto.Migration

  def change do
    create(index(:address_token_balances, [:block_number]))
  end
end
