defmodule Explorer.Repo.Migrations.AddIndexesForBlockRewardQuery do
  use Ecto.Migration

  def change do
    create(index(:blocks, [:number]))
    create(index(:emission_rewards, [:block_range]))
  end
end
