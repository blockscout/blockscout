defmodule Explorer.Repo.Optimism.Migrations.HoloceneSupport do
  use Ecto.Migration

  def change do
    create table(:op_eip1559_config_updates, primary_key: false) do
      add(:l2_block_number, :bigint, null: false, primary_key: true)
      add(:l2_block_hash, :bytea, null: false)
      add(:base_fee_max_change_denominator, :integer, null: false)
      add(:elasticity_multiplier, :integer, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
