defmodule Explorer.Repo.Celo.Migrations.RemoveUnusedFieldsFromValidatorGroupVotes do
  use Ecto.Migration

  def change do
    alter table(:celo_validator_group_votes) do
      remove(:value, :numeric, precision: 100, null: false, default: 0)
      remove(:units, :numeric, precision: 100, null: false, default: 0)
    end
  end
end
