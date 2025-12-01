defmodule Explorer.Repo.Migrations.CreateAddressIdsToAddressHashes do
  use Ecto.Migration

  def change do
    create table(:address_ids_to_address_hashes, primary_key: false) do
      add(:address_id, :bigserial, primary_key: true)
      add(:address_hash, :bytea, null: false)
    end

    create(unique_index(:address_ids_to_address_hashes, [:address_hash]))
  end
end
