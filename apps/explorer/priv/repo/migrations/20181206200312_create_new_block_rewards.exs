defmodule Explorer.Repo.Migrations.CreateNewBlockRewards do
  use Ecto.Migration

  def change do
    create table(:block_rewards, primary_key: false) do
      add(:address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      add(:address_type, :string, null: false)
      add(:block_hash, references(:blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: false)
      add(:reward, :numeric, precision: 100, null: true)

      timestamps(null: false, type: :utc_datetime)
    end

    create(unique_index(:block_rewards, [:address_hash, :address_type, :block_hash]))
  end
end
