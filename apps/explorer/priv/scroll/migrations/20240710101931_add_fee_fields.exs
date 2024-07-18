defmodule Explorer.Repo.Scroll.Migrations.AddFeeFields do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:l1_fee, :numeric, precision: 100, null: true)
    end

    execute(
      "CREATE TYPE scroll_l1_fee_param_names AS ENUM ('overhead', 'scalar')",
      "DROP TYPE scroll_l1_fee_param_names"
    )

    create table(:scroll_l1_fee_params, primary_key: false) do
      add(:block_number, :bigint, null: false, primary_key: true)
      add(:tx_index, :integer, null: false, primary_key: true)
      add(:name, :scroll_l1_fee_param_names, null: false, primary_key: true)
      add(:value, :bigint, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
