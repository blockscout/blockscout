defmodule Explorer.Repo.Migrations.AddTransactionsHashBlockNumberBlockHashIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :transactions,
        ~w(hash block_number block_hash)a,
        concurrently: true
      )
    )
  end
end
