defmodule Explorer.Repo.Migrations.EmissionRewardsAddPrimaryKey do
  use Ecto.Migration

  def change do
    alter table(:emission_rewards) do
      modify(:block_range, :int8range, primary_key: true)
    end
  end
end
