defmodule Explorer.Repo.Celo.Migrations.AddValidatorGroupVotes do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE celo_validator_group_vote_type AS ENUM ('activated', 'revoked')",
      "DROP TYPE celo_validator_group_vote_type"
    )

    create table(:celo_validator_group_votes, primary_key: false) do
      add(
        :account_address_hash,
        references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      add(
        :group_address_hash,
        references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false
      )

      add(:value, :numeric, precision: 100, null: false)
      add(:units, :numeric, precision: 100, null: false)

      add(:type, :celo_validator_group_vote_type, null: false)

      add(:transaction_hash, :bytea, null: false, primary_key: true)

      add(:block_number, :integer, null: false)
      add(:block_hash, :bytea, null: false)

      timestamps()
    end
  end
end
