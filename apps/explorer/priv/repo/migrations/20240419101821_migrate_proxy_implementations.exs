defmodule Explorer.Repo.Migrations.MigrateProxyImplementations do
  use Ecto.Migration

  def change do
    execute("""
    INSERT INTO proxy_implementations(proxy_address_hash, implementation_address_hash)
    SELECT address_hash, implementation_address_hash
    FROM smart_contracts
    """)
  end
end
