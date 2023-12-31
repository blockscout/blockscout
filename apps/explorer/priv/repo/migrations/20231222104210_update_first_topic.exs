defmodule Explorer.Repo.Migrations.MigrateFirstTopic do
  use Ecto.Migration

  def change do
    execute("""
      UPDATE logs SET first_topic_id = topic.id
      FROM logs l INNER JOIN log_first_topics topic
      ON l.first_topic = topic.hash
      WHERE logs.first_topic = topic.hash;
    """)
  end
end
