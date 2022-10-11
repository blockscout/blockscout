defmodule Explorer.Repo.Migrations.RenameCeloAccountsEpochsFields do
  use Ecto.Migration

  def change do
    rename(table(:celo_accounts_epochs), :locked_gold, to: :total_locked_gold)
    rename(table(:celo_accounts_epochs), :activated_gold, to: :nonvoting_locked_gold)
  end
end
