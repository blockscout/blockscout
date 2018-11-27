defmodule Explorer.Repo.Migrations.AddNonceToAddresses do
  @moduledoc """
  Use `priv/repo/migrations/scripts/20181126182700_migrate_address_nonce.sql` to migrate data.

  ```sh
  mix ecto.migrate
  psql -d $DATABASE -a -f priv/repo/migrations/scripts/20181126182700_migrate_address_nonce.sql
  ```
  """

  use Ecto.Migration

  def up do
    # Add nonce
    alter table(:addresses) do
      add(:nonce, :integer)
    end
  end

  def down do
    # Remove nonce
    alter table(:addresses) do
      remove(:nonce)
    end
  end
end
