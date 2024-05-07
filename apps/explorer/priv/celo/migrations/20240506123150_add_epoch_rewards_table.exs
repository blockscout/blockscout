defmodule Explorer.Repo.Celo.Migrations.AddEpochRewardsTable do
  use Ecto.Migration

  def change do
    create table(:celo_epoch_rewards, primary_key: false) do
      add(:reserve_bolster, :numeric, precision: 100, null: false)
      add(:per_validator, :numeric, precision: 100, null: false)
      add(:voters_total, :numeric, precision: 100, null: false)
      add(:community_total, :numeric, precision: 100, null: false)
      add(:carbon_offsetting_total, :numeric, precision: 100, null: false)

      add(
        :block_hash,
        references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      timestamps()
    end
  end
end
