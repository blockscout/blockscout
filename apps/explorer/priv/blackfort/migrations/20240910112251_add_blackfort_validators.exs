defmodule Explorer.Repo.Blackfort.Migrations.AddBlackfortValidators do
  use Ecto.Migration

  def change do
    create table(:validators_blackfort, primary_key: false) do
      add(:address_hash, :bytea, null: false, primary_key: true)
      add(:name, :string)
      add(:commission, :smallint)
      add(:self_bonded_amount, :numeric, precision: 100)
      add(:delegated_amount, :numeric, precision: 100)
      add(:slashing_status_is_slashed, :boolean, default: false)
      add(:slashing_status_by_block, :bigint)
      add(:slashing_status_multiplier, :integer)

      timestamps()
    end

    create_if_not_exists(index(:validators_blackfort, ["address_hash ASC"]))
  end
end
