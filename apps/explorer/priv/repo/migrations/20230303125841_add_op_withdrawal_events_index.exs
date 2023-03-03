defmodule Explorer.Repo.Migrations.AddOpWithdrawalEventsIndex do
  use Ecto.Migration

  def change do
    create(index(:op_withdrawal_events, [:l1_block_number]))
  end
end
