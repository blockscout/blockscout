defmodule Explorer.Repo.Migrations.RenameCeloWithdrawalToPendingCelo do
  use Ecto.Migration

  def change do
    rename(table(:celo_withdrawal), to: table(:pending_celo))
  end
end
