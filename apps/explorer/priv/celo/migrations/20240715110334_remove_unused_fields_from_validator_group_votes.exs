defmodule Explorer.Repo.Celo.Migrations.RemoveUnusedFieldsFromValidatorGroupVotes do
  use Ecto.Migration

  def change do
    alter table(:celo_validator_group_votes) do
      remove(:value)
      remove(:units)
    end
  end
end
