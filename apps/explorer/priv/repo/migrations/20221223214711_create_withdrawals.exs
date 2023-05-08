defmodule Explorer.Repo.Migrations.CreateWithdrawals do
  use Ecto.Migration

  def change do
    create table(:withdrawals, primary_key: false) do
      add(:index, :integer, null: false, primary_key: true)
      add(:validator_index, :integer, null: false)
      add(:amount, :numeric, precision: 100, null: false)

      timestamps(null: false, type: :utc_datetime_usec)

      add(:address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      add(:block_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
    end

    create(index(:withdrawals, [:address_hash]))
    create(index(:withdrawals, [:block_hash]))
  end
end
