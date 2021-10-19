defmodule Explorer.Repo.Migrations.AddBlockRewardsBlockNumberIndex do
  use Ecto.Migration

  def change do
    create(index(:block_rewards, [:block_number]))
  end
end
