defmodule Explorer.Repo.Migrations.RefactorProxyImplementations do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE proxy_implementations
    SET proxy_type     = NULL,
        address_hashes = ARRAY []::bytea[],
        names          = ARRAY []::bytea[]
    WHERE proxy_type IN ('eip930', 'unknown')
    OR address_hashes = ARRAY ['\\x0000000000000000000000000000000000000000'::bytea]
    """)

    alter table(:proxy_implementations) do
      add(:conflicting_proxy_types, {:array, :proxy_type})
      add(:conflicting_address_hashes, {:array, {:array, :bytea}})
    end

    execute(
      "ALTER TYPE proxy_type RENAME VALUE 'eip930' TO 'eip1967_oz'",
      "ALTER TYPE proxy_type RENAME VALUE 'eip1967_oz' TO 'eip930'"
    )

    execute(
      "ALTER TYPE proxy_type RENAME VALUE 'unknown' TO 'eip1967_beacon'",
      "ALTER TYPE proxy_type RENAME VALUE 'eip1967_beacon' TO 'unknown'"
    )
  end
end
