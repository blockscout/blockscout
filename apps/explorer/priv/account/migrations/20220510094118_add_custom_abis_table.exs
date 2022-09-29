defmodule Explorer.Repo.Account.Migrations.AddCustomAbisTable do
  use Ecto.Migration

  def change do
    create table(:account_custom_abis, primary_key: false) do
      add(:id, :serial, null: false, primary_key: true)
      add(:identity_id, references(:account_identities, column: :id, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:address_hash, :bytea, null: false)
      add(:abi, :jsonb, null: false)

      timestamps()
    end

    create(unique_index(:account_custom_abis, [:identity_id, :address_hash]))
    create(index(:account_custom_abis, [:identity_id]))
  end
end
