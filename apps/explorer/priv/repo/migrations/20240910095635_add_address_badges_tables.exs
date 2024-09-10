defmodule Explorer.Repo.Migrations.AddAddressBadgesTables do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE address_badge_category AS ENUM ('scam')",
      "DROP TYPE address_badge_category"
    )

    create table(:address_badges, primary_key: false) do
      add(:id, :serial, null: false, primary_key: true)
      add(:category, :address_badge_category, null: false)
      add(:content, :string, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:address_badges, [:category, :content]))

    create table(:address_badge_mappings, primary_key: false) do
      add(:badge_id, references(:address_badges, column: :id, type: :integer, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      add(:address_hash, references(:addresses, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:address_badge_mappings, [:address_hash]))
  end
end
