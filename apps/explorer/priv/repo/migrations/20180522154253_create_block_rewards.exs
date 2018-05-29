defmodule Explorer.Repo.Migrations.CreateBlockRewards do
  use Ecto.Migration

  def change do
    create table(:block_rewards, primary_key: false) do
      add(:block_range, :int8range)
      add(:reward, :decimal)
    end

    execute("CREATE EXTENSION IF NOT EXISTS btree_gist")

    create(constraint(:block_rewards, :no_overlapping_ranges, exclude: ~s|gist (block_range WITH &&)|))
  end
end
