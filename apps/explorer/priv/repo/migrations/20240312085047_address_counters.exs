defmodule Explorer.Repo.Migrations.AddressCounters do
  use Ecto.Migration

  def change do
    create table("address_counters", primary_key: false) do
      add(:hash, :bytea, null: false, primary_key: true)
      add(:token_holders_count, :integer, null: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
