defmodule Explorer.Repo.Migrations.DropFirstTopicColumnInLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      remove(:first_topic)
    end
  end
end
