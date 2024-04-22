defmodule Explorer.Repo.Migrations.AddOpWithdrawalIndex do
  use Ecto.Migration

  def change do
    create(index(:op_withdrawals, :l2_transaction_hash))
  end
end
