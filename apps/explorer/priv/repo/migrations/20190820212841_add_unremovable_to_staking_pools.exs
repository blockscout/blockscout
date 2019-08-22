defmodule Explorer.Repo.Migrations.AddUnremovableToStakingPools do
  use Ecto.Migration

  def change do
    alter table(:staking_pools) do
      add(:is_unremovable, :boolean, default: false, null: false)
    end
  end
end
