defmodule Explorer.Repo.Migrations.AddCeloValidatorGroupVotes do
  use Ecto.Migration

  def change do
    create table(:celo_validator_group_votes, primary_key: false) do
      add(:block_hash, references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      add(:group_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:previous_block_active_votes, :numeric, precision: 100)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:celo_validator_group_votes, [:block_hash, :group_hash]))
  end
end
