defmodule Explorer.Repo.Arbitrum.Migrations.AddUnconfirmedBlocksIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(:arbitrum_batch_l2_blocks, ["confirmation_id, block_number DESC"],
        where: "confirmation_id IS NULL",
        name: :arbitrum_batch_l2_blocks_unconfirmed_blocks_index,
        concurrently: true
      )
    )
  end
end
