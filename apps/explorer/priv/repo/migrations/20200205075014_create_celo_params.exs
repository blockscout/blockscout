defmodule Explorer.Repo.Migrations.CreateCeloParams do
  use Ecto.Migration

  def change do
    create table(:celo_params) do
      add(:name, :string, size: 256, null: false)
      add(:number_value, :numeric, precision: 100)
      add(:block_number, :integer)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_params, [:name], unique: true))
  end
end
