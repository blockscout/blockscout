defmodule Explorer.Repo.Migrations.AddTokensCatalogedIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :tokens,
        ~w(cataloged)a,
        name: :uncataloged_tokens,
        where: ~s|"cataloged" = false|,
        concurrently: true
      )
    )
  end
end
