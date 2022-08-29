defmodule Explorer.Repo.Migrations.LogsContractTopicIndex do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create_if_not_exists(index(:logs, [:address_hash, :first_topic, :block_number], concurrently: true))
  end
end
