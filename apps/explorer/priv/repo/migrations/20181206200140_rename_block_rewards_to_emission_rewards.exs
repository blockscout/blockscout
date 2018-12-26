defmodule Explorer.Repo.Migrations.RenameBlockRewardsToEmissionRewards do
  use Ecto.Migration

  def change do
    rename(table(:block_rewards), to: table(:emission_rewards))
  end
end
