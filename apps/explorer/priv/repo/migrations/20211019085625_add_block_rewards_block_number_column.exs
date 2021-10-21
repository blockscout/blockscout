defmodule Explorer.Repo.Migrations.AddBlockRewardsBlockNumberColumn do
  use Ecto.Migration

  def change do
    alter table(:block_rewards) do
      add(:block_number, :integer, null: true)
    end
  end
end
