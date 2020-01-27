defmodule Explorer.Repo.Migrations.CreateCeloVoters do
  use Ecto.Migration

  def change do
    create table(:celo_voters) do
      add(:group_address_hash, :bytea, null: false)
      add(:voter_address_hash, :bytea, null: false)
      add(:pending, :numeric, precision: 100)
      add(:active, :numeric, precision: 100)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_voters, [:group_address_hash, :voter_address_hash], unique: true))
  end
end
