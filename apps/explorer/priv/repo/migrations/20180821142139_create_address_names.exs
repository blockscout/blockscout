defmodule Explorer.Repo.Migrations.CreateAddressNames do
  use Ecto.Migration

  def change do
    create table(:address_names, primary_key: false) do
      add(:address_hash, :bytea, null: false)
      add(:name, :string, null: false)
      add(:primary, :boolean, null: false, default: false)

      timestamps()
    end

    # Only 1 primary per address
    create(unique_index(:address_names, [:address_hash], where: ~s|"primary" = true|))
    # No duplicate names per address
    create(unique_index(:address_names, [:address_hash, :name], name: :unique_address_names))

    insert_names_from_existing_data_query = """
    INSERT INTO address_names (address_hash, name, "primary", inserted_at, updated_at)
      (
        SELECT address_hash, name, true, NOW(), NOW()
        FROM smart_contracts WHERE name IS NOT NULL

        UNION

        SELECT contract_address_hash, name, false, NOW(), NOW()
        FROM tokens WHERE name IS NOT NULL
      );
    """

    execute(insert_names_from_existing_data_query)
  end
end
