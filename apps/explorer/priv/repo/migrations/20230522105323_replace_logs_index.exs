defmodule Explorer.Repo.Migrations.ReplaceLogsIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(:logs, [:address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST"], concurrently: true)
    )
  end
end
