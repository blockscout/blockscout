defmodule Explorer.Repo.Migrations.AddLogsAddressHashTransactionHashIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :logs,
        ~w(address_hash transaction_hash)a,
        concurrently: true
      )
    )
  end
end
