defmodule Explorer.Repo.Migrations.AddBlockConsensusToTokenTransfers do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    alter table(:token_transfers) do
      add_if_not_exists(:block_consensus, :boolean, default: true)
    end

    create_if_not_exists(index(:token_transfers, :block_consensus, concurrently: true))
  end
end
