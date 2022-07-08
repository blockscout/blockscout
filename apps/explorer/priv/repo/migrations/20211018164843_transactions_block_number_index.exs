defmodule Explorer.Repo.Migrations.TransactionsBlockNumberIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :transactions,
        ~w(block_number)a,
        concurrently: true
      )
    )
  end
end
