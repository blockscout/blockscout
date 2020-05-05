defmodule Explorer.Repo.Migrations.DelegatorsDeletedColum do
  use Ecto.Migration

  def change do
    alter table(:staking_pools_delegators) do
      add(:is_active, :boolean, default: true)
      add(:is_deleted, :boolean, default: false)
    end
  end
end
