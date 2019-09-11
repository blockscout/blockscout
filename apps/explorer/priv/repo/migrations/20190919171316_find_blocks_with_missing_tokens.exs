defmodule Explorer.Repo.Migrations.FindBlocksWithMissingTokens do
  @moduledoc """
  Use `priv/repo/migrations/scripts/20190919171316_find_blocks_with_missing_tokens.sql`
  to find all the block number with missing tokens *before* running this migration.

  ```sh
  mix ecto.migrate
  psql -d $DATABASE -a -f priv/repo/migrations/scripts/20181108205650_additional_internal_transaction_constraints.sql
  ```

  NOTE: if the script above is not run, all the existing numbers will be refetched.
  """

  use Ecto.Migration

  def up do
    create_if_not_exists table(:blocks_to_invalidate_missing_tt, primary_key: false) do
      add(:block_number, :bigint)
      add(:refetched, :boolean)
    end

    execute("""
    INSERT INTO blocks_to_invalidate_missing_tt
    SELECT DISTINCT number FROM blocks
    WHERE NOT EXISTS (SELECT * FROM blocks_to_invalidate_missing_tt);
    """)
  end

  def down do
    drop_if_exists(table(:blocks_to_invalidate_missing_tt))
  end
end
