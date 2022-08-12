defmodule Explorer.Repo.Migrations.AddReserveBolsterToEpochRewards do
  use Ecto.Migration

  def change do
    alter table(:celo_epoch_rewards) do
      add(:reserve_bolster, :numeric, precision: 100, default: 0, null: false)
    end
  end
end
