defmodule Explorer.Repo.Migrations.AddAddressIdToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:address_id, :bigint)
    end
  end
end
