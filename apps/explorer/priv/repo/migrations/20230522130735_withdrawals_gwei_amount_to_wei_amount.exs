defmodule Explorer.Repo.Migrations.WithdrawalsGweiAmountToWeiAmount do
  use Ecto.Migration

  def change do
    execute("UPDATE withdrawals SET amount = amount * 1000000000")
  end
end
