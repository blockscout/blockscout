defmodule Explorer.Repo.Migrations.WithdrawalsFromGweiToMgno do
  use Ecto.Migration

  def up do
    execute("UPDATE withdrawals SET amount = amount / 32")
  end

  def down do
    execute("UPDATE withdrawals SET amount = amount * 32")
  end
end
