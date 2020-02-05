defmodule Explorer.Repo.Migrations.AddActiveVotesToGroups do
  use Ecto.Migration

  def change do
    alter table(:celo_validator_group) do
      add(:active_votes, :numeric, precision: 100)
      add(:num_members, :integer)
    end
  end
end
