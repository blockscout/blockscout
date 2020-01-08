defmodule Explorer.Repo.Migrations.CreateCeloAccount do
  use Ecto.Migration

  def change do
    create table(:celo_account) do
      add(:address, :bytea, null: false)
      add(:account_type, :string)
      add(:nonvoting_locked_gold, :numeric, precision: 100)
      add(:locked_gold, :numeric, precision: 100)
      add(:name, :string, size: 2048)
      add(:url, :string, size: 2048)
      add(:attestations_requested, :integer)
      add(:attestations_fulfilled, :integer)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_account, [:address], unique: true))

    create table(:celo_validator) do
      add(:address, :bytea, null: false)
      # affiliation
      add(:group_address_hash, :bytea)
      add(:signer_address_hash, :bytea)
      add(:score, :numeric, precision: 100)
      add(:member, :integer)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_validator, [:address], unique: true))
    create(index(:celo_validator, [:group_address_hash]))

    create table(:celo_validator_group) do
      add(:address, :bytea, null: false)
      add(:commission, :numeric, precision: 100)
      add(:votes, :numeric, precision: 100)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_validator_group, [:address], unique: true))

    create table(:celo_withdrawal) do
      add(:account_address, :bytea, null: false)
      add(:index, :integer, null: false)
      add(:amount, :numeric, precision: 100)
      add(:timestamp, :utc_datetime_usec, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_withdrawal, [:account_address, :index], unique: true))

    create table(:celo_validator_history) do
      add(:index, :integer, null: false)
      add(:block_number, :integer, null: false)
      add(:address, :bytea, null: false)
      add(:online, :boolean, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_validator_history, [:block_number, :index], unique: true))

    create table(:celo_signers) do
      add(:address, :bytea, null: false)
      add(:signer, :bytea, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:celo_signers, [:address, :signer], unique: true))
    create(index(:celo_signers, [:address]))
    create(index(:celo_signers, [:signer]))
  end
end
