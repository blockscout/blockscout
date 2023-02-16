defmodule Explorer.Repo.Migrations.AddValidatorsAndConstantsTables do
  use Ecto.Migration

  def change do
    create table(:constants, primary_key: false) do
      add(:key, :string, primary_key: true, null: false)
      add(:value, :string)

      timestamps()
    end

    create table(:validators, primary_key: false) do
      add(:address_hash, :bytea, primary_key: true, null: false)
      add(:is_validator, :boolean)
      add(:payout_key_hash, :bytea)
      add(:last_block_updated_at, :bigint)

      timestamps()
    end
  end
end
