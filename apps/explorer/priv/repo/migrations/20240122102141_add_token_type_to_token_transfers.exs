defmodule Explorer.Repo.Migrations.AddTokenTypeToTokenTransfers do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    alter table(:token_transfers) do
      add_if_not_exists(:token_type, :string)
    end

    create_if_not_exists(index(:token_transfers, :token_type, concurrently: true))
  end
end
