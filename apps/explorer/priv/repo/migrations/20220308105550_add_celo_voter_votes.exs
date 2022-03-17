defmodule Explorer.Repo.Migrations.AddCeloVoterVotes do
  use Ecto.Migration

  def change do
    create table(:celo_voter_votes, primary_key: false) do
      add(:account_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:active_votes, :numeric, precision: 100, null: false)
      add(:block_hash, references(:blocks, column: :hash, type: :bytea, on_delete: :delete_all), null: false)
      add(:block_number, :integer, null: false)
      add(:group_hash, :bytea, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:celo_voter_votes, [:account_hash, :block_hash, :group_hash]))
  end
end
