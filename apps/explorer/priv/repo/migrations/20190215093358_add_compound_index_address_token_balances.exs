defmodule Explorer.Repo.Migrations.AddCompoundIndexAddressTokenBalances do
  use Ecto.Migration

  def change do
    create(index(:address_current_token_balances, [:block_number], name: :address_cur_token_balances_index))
  end
end
