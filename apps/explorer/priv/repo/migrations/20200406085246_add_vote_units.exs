defmodule Explorer.Repo.Migrations.AddVoteUnits do
  use Ecto.Migration

  def change do
    alter table(:celo_voters) do
      add(:units, :numeric, precision: 100)
      add(:num_members, :integer)
    end

    alter table(:celo_validator_group) do
      add(:total_units, :numeric, precision: 100)
    end
  end
end
