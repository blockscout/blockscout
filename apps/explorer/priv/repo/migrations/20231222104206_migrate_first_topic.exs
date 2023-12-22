defmodule Explorer.Repo.Migrations.MigrateFirstTopic do
  use Ecto.Migration

  def change do
    execute("""
      INSERT INTO log_first_topics(hash, inserted_at, updated_at)
      SELECT DISTINCT first_topic, now(), now() FROM logs;
    """)

    execute("""
      UPDATE logs SET log_first_topic_id = topic.id
      FROM logs l LEFT JOIN log_first_topics topic
      ON l.first_topic = topic.hash
      WHERE logs.first_topic = topic.hash;
    """)
  end
end
