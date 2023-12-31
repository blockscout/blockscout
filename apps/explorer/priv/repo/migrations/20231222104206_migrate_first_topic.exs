defmodule Explorer.Repo.Migrations.MigrateFirstTopic do
  use Ecto.Migration

  def change do
    execute("""
      INSERT INTO log_first_topics(hash, inserted_at, updated_at)
      SELECT DISTINCT first_topic, now(), now() FROM logs
      WHERE first_topic IS NOT NULL;
    """)
  end
end
