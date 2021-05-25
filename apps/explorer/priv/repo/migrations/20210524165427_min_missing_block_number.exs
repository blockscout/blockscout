defmodule Explorer.Repo.Migrations.MinMissingBlockNumber do
  use Ecto.Migration

  def change do
    insert_initial_genesis_block = """
    INSERT INTO last_fetched_counters (counter_type, value, inserted_at, updated_at)
      VALUES ('min_missing_block_number', 0, NOW(), NOW());
    """

    execute(insert_initial_genesis_block)
  end
end
