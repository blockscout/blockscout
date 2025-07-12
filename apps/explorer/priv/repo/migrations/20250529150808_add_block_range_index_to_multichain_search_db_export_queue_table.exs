defmodule Explorer.Repo.Migrations.AddBlockRangeIndexToMultichainSearchDbMainExportQueueTable do
  use Ecto.Migration

  def change do
    execute(
      """
      CREATE INDEX multichain_search_db_main_export_queue_upper_block_range_index ON multichain_search_db_main_export_queue (upper(block_range) DESC);
      """,
      """
      DROP INDEX multichain_search_db_main_export_queue_upper_block_range_index;
      """
    )
  end
end
