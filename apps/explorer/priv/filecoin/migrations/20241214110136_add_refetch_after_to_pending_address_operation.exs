defmodule Explorer.Repo.Filecoin.Migrations.AddRefetchAfterToPendingAddressOperation do
  use Ecto.Migration

  def up do
    alter table(:filecoin_pending_address_operations) do
      add(:refetch_after, :utc_datetime_usec)
      remove(:http_status_code)
    end
  end

  def down do
    alter table(:filecoin_pending_address_operations) do
      remove(:refetch_after)
      add(:http_status_code, :smallint)
    end
  end
end
