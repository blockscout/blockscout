defmodule Explorer.Repo.Migrations.AddAddressBadgesTables do
  use Ecto.Migration

  def change do
    create table(:scam_address_badge_mappings, primary_key: false) do
      add(:address_hash, references(:addresses, column: :hash, type: :bytea, on_delete: :delete_all),
        null: false,
        primary_key: true
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
