defmodule Explorer.Repo.Migrations.CreateTokenInstanceMetadataRefetchAttemptsTable do
  use Ecto.Migration

  def change do
    create table(:token_instance_metadata_refetch_attempts, primary_key: false) do
      add(:token_contract_address_hash, :bytea, null: false, primary_key: true)
      add(:token_id, :numeric, precision: 78, scale: 0, null: false, primary_key: true)
      add(:retries_number, :smallint)

      timestamps()
    end

    create(index(:token_instance_metadata_refetch_attempts, [:token_contract_address_hash, :token_id]))
  end
end
