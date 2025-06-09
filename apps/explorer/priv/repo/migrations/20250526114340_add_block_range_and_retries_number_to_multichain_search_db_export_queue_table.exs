defmodule Explorer.Repo.Migrations.AddBlockRangeAndRetriesNumberToMultichainSearchDbMainExportQueueTable do
  use Ecto.Migration

  def change do
    alter table(:multichain_search_db_main_export_queue) do
      add(:block_range, :int8range, null: true)
      add(:retries_number, :smallint, null: true)
    end
  end
end
