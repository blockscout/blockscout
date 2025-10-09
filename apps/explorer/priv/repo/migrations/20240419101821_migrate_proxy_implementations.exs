defmodule Explorer.Repo.Migrations.MigrateProxyImplementations do
  use Ecto.Migration

  def change do
    execute("""
    INSERT INTO proxy_implementations(proxy_address_hash, address_hashes, names, inserted_at, updated_at)
    SELECT address_hash, ARRAY [implementation_address_hash], CASE WHEN implementation_name IS NULL THEN '{}' ELSE ARRAY [implementation_name] END, implementation_fetched_at, implementation_fetched_at
    FROM smart_contracts
    WHERE implementation_fetched_at IS NOT NULL
    AND implementation_address_hash IS NOT NULL
    """)
  end
end
