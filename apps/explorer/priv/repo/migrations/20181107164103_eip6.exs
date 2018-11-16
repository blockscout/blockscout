defmodule Explorer.Repo.Migrations.EIP6 do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE internal_transactions DROP CONSTRAINT suicide_has_from_and_to_address_hashes")

    create(
      constraint(
        :internal_transactions,
        :selfdestruct_or_suicide_has_from_and_to_address_hashes,
        check: """
        (type != 'selfdestruct' AND type != 'suicide') OR
        (from_address_hash IS NOT NULL AND gas IS NULL AND to_address_hash IS NOT NULL)
        """
      )
    )
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
