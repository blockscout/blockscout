defmodule Explorer.Repo.Migrations.CreateCeloClaims do
  use Ecto.Migration

  def change do
    create table(:celo_claims) do
      add(:address, :bytea, null: false)
      add(:type, :string, size: 256, null: false)
      add(:element, :string, size: 2048, null: true)
      add(:verified, :boolean, null: false)
      add(:timestamp, :utc_datetime_usec, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_claims, [:address, :type, :element], unique: true))
  end
end
