defmodule Explorer.Repo.Optimism.Migrations.HoloceneClear do
  use Ecto.Migration

  def change do
    execute("TRUNCATE TABLE op_eip1559_config_updates;")

    execute(
      "DELETE FROM last_fetched_counters WHERE counter_type = 'optimism_eip1559_config_updates_fetcher_last_l2_block_hash';"
    )
  end
end
