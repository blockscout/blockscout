defmodule Explorer.Repo.Migrations.CreateCeloAccount do
    use Ecto.Migration
  
    def change do
        create table(:celo_account) do
            add(:address, :bytea, null: false)
            add(:account_type, :string)
            add(:gold, :numeric, precision: 100)
            add(:usd, :numeric, precision: 100)
            add(:locked_gold, :numeric, precision: 100)
            add(:rewards, :numeric, precision: 100)
            add(:notice_period, :integer)

            timestamps(null: false, type: :utc_datetime_usec)
        end

        create(index(:celo_account, [:address], unique: true))

        create table(:celo_validator) do
            add(:address, :bytea, null: false)
            add(:name, :string)
            add(:url, :string)
            add(:group_address_hash, :bytea, null: false)

            timestamps(null: false, type: :utc_datetime_usec)
        end

        create(index(:celo_validator, [:address], unique: true))

        create table(:celo_validator_group) do
            add(:address, :bytea, null: false)
            add(:name, :string)
            add(:url, :string)
            add(:commission, :numeric, precision: 100)
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
            add(:validator_address, :bytea, null: false)
            timestamps(null: false, type: :utc_datetime_usec)
        end

        create(index(:celo_validator_history, [:validator_address, :block_number, :index], unique: true))

    end
end

