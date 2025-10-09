defmodule Explorer.Repo.Arbitrum.Migrations.AddDaInfo do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE arbitrum_da_containers_types AS ENUM ('in_blob4844', 'in_calldata', 'in_celestia', 'in_anytrust')",
      "DROP TYPE arbitrum_da_containers_types"
    )

    alter table(:arbitrum_l1_batches) do
      add(:batch_container, :arbitrum_da_containers_types)
    end

    create table(:arbitrum_da_multi_purpose, primary_key: false) do
      add(:data_key, :bytea, null: false, primary_key: true)
      add(:data_type, :integer, null: false)
      add(:data, :map, null: false)
      add(:batch_number, :integer)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:arbitrum_da_multi_purpose, [:data_type, :data_key]))
    create(index(:arbitrum_da_multi_purpose, [:data_type, :batch_number]))
  end
end
