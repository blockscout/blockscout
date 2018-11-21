defmodule Explorer.Repo.Migrations.AddBlockNumberToTokenTransfers do
  @moduledoc """
  Use `priv/repo/migrations/scripts/20181121170616_token_transfers_update_block_number_in_batches.sql` to migrate data.

  ```sh
  mix ecto.migrate
  psql -d $DATABASE -a -f priv/repo/migrations/scripts/20181121170616_token_transfers_update_block_number_in_batches.sql
  ```
  """

  use Ecto.Migration

  def change do
    alter table(:token_transfers) do
      add(:block_number, :integer)
    end
  end
end
