defmodule Explorer.Repo.Migrations.CreateAddressContractCodeFetchAttemptsTable do
  use Ecto.Migration

  def change do
    create table(:address_contract_code_fetch_attempts, primary_key: false) do
      add(:address_hash, :bytea, null: false, primary_key: true)
      add(:retries_number, :smallint)

      timestamps()
    end

    create(index(:address_contract_code_fetch_attempts, [:address_hash]))
  end
end
