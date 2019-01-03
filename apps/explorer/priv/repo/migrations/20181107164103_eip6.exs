defmodule Explorer.Repo.Migrations.EIP6 do
  @moduledoc """
  Use `priv/repo/migrations/scripts/20181107164103_eip6.sql` to migrate data and validate constraint.

  ```sh
  mix ecto.migrate
  psql -d $DATABASE -a -f priv/repo/migrations/scripts/20181107164103_eip6.sql
  ```
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE internal_transactions DROP CONSTRAINT suicide_has_from_and_to_address_hashes")

    # `NOT VALID` skips checking pre-existing rows. Use `priv/repo/migrations/scripts/20181107164103_eip6.sql` to
    # migrate data and validate constraints
    execute("""
    ALTER TABLE internal_transactions
    ADD CONSTRAINT selfdestruct_has_from_and_to_address
    CHECK (type != 'selfdestruct' OR (from_address_hash IS NOT NULL AND gas IS NULL AND to_address_hash IS NOT NULL))
    NOT VALID
    """)
  end

  def down do
    execute("ALTER TABLE internal_transactions DROP CONSTRAINT selfdestruct_has_from_and_to_address_hashes")

    create(
      constraint(
        :internal_transactions,
        :suicide_has_from_and_to_address_hashes,
        check: """
        type != 'suicide' OR
        (from_address_hash IS NOT NULL AND gas IS NULL AND to_address_hash IS NOT NULL)
        """
      )
    )
  end
end
