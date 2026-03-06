defmodule Explorer.Repo.Migrations.ChangeAddressNamesPrimaryKey do
  use Ecto.Migration

  # This migration converts the address_names table to use a composite primary key
  # on (address_hash, name) instead of the id column.
  #
  # The unique index "unique_address_names" on (address_hash, name) already exists
  # (created in migration 20180821142139_create_address_names.exs).
  # We will promote this existing index to be the primary key.

  def up do
    # Drop the old primary key constraint on id
    execute("ALTER TABLE address_names DROP CONSTRAINT address_names_pkey")

    # Remove the id column
    alter table(:address_names) do
      remove(:id)
    end

    # Promote the existing unique_address_names index to be the primary key
    execute("ALTER TABLE address_names ADD PRIMARY KEY USING INDEX unique_address_names")
  end

  def down do
    # Drop the composite primary key
    execute("ALTER TABLE address_names DROP CONSTRAINT address_names_pkey")

    # Recreate the sequence for the id column (mimicking original SERIAL behavior)
    execute("CREATE SEQUENCE address_names_id_seq")

    # Re-add the id column with sequence backing and NOT NULL
    alter table(:address_names) do
      add(:id, :integer, null: false, default: fragment("nextval('address_names_id_seq'::regclass)"))
    end

    # Set sequence ownership to the id column
    execute("ALTER SEQUENCE address_names_id_seq OWNED BY address_names.id")

    # Restore the original id-based primary key
    execute("ALTER TABLE address_names ADD PRIMARY KEY (id)")

    # Recreate the unique index for (address_hash, name) that was used in upsert operations
    create(unique_index(:address_names, [:address_hash, :name], name: :unique_address_names))
  end
end
