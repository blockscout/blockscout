defmodule Explorer.Repo.Stability.Migrations.AddStabilityValidators do
  use Ecto.Migration

  def change do
    create table(:validators_stability, primary_key: false) do
      add(:address_hash, :bytea, null: false, primary_key: true)
      add(:state, :integer, default: 0)

      timestamps()
    end

    create_if_not_exists(index(:validators_stability, ["state ASC", "address_hash ASC"]))
  end
end
