defmodule Explorer.Repo.Migrations.AddIsEmptyIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :blocks,
        ~w(consensus)a,
        name: :empty_consensus_blocks,
        where: "is_empty IS NULL",
        concurrently: true
      )
    )
  end
end
