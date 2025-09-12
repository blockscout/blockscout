defmodule Explorer.Repo.Celo.Migrations.CreateAccount do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE celo_account_type AS ENUM ('regular', 'validator', 'group')",
      "DROP TYPE celo_account_type"
    )

    create table(:celo_accounts, primary_key: false) do
      add(
        :address_hash,
        references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea),
        null: false,
        primary_key: true
      )

      add(
        :type,
        :celo_account_type,
        null: false,
        default: "regular"
      )

      add(:name, :string)
      add(:metadata_url, :string)
      add(:nonvoting_locked_celo, :numeric, precision: 100, null: false)
      add(:locked_celo, :numeric, precision: 100, null: false)

      add(
        :vote_signer_address_hash,
        references(:addresses, column: :hash, type: :bytea),
        null: true
      )

      add(
        :validator_signer_address_hash,
        references(:addresses, column: :hash, type: :bytea),
        null: true
      )

      add(
        :attestation_signer_address_hash,
        references(:addresses, column: :hash, type: :bytea),
        null: true
      )

      timestamps()
    end

    create(constraint(:celo_accounts, :nonvoting_locked_celo_nonnegative, check: "nonvoting_locked_celo >= 0"))
    create(constraint(:celo_accounts, :locked_celo_nonnegative, check: "locked_celo >= 0"))
  end
end
