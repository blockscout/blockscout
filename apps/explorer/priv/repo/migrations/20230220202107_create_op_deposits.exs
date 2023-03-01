defmodule Explorer.Repo.Migrations.CreateOpDeposits do
  use Ecto.Migration

  def change do
    create table(:op_deposits, primary_key: false) do
      add(:l1_block_number, :bigint, null: false)
      add(:l1_block_timestamp, :"timestamp without time zone", null: false)
      add(:l1_transaction_hash, :bytea, null: false)
      add(:l1_transaction_origin, :bytea, null: false)
      add(:l2_transaction_hash, :bytea, null: false, primary_key: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:op_deposits, [:l1_block_number]))
  end
end
