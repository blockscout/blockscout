defmodule Explorer.Repo.Migrations.LogsContractTopicLogIndexIndex do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create_if_not_exists(index(:logs, [:address_hash, :first_topic, :block_number], concurrently: true))

    #above index obsoletes existing address_hash index
    drop_if_exists(index(:logs,[:address_hash], concurrently: true))
  end
end
