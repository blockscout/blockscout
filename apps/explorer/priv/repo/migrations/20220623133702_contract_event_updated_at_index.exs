defmodule Explorer.Repo.Migrations.ContractEventUpdatedAtIndex do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create(index("celo_contract_events", [:updated_at], concurrently: true))
  end
end
