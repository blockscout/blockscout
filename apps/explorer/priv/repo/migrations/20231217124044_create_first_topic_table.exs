defmodule Explorer.Repo.Migrations.CreateLogFirstTopicTable do
  use Ecto.Migration

  def change do
    create table(:log_first_topics, primary_key: false) do
      add(:id, :bigserial, null: false)
      add(:hash, :bytea, null: false, primary_key: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:log_first_topics, [:id]))

    alter table(:logs) do
      add(:first_topic_id, references(:log_first_topics, column: :id, type: :bigserial), null: true)
    end
  end
end
