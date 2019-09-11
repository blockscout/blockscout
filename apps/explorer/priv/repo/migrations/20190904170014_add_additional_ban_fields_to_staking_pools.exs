defmodule Explorer.Repo.Migrations.AddAdditionalBanFieldsToStakingPools do
  use Ecto.Migration

  def change do
    alter table(:staking_pools) do
      add(:are_delegators_banned, :boolean, default: false)
      add(:ban_reason, :string)
      add(:banned_delegators_until, :bigint)
    end
  end
end
