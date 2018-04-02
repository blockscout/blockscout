defmodule Explorer.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs) do
      add :data, :text, null: false
      add :index, :integer, null: false
      add :type, :string, null: false
      add :first_topic, :string, null: true
      add :second_topic, :string, null: true
      add :third_topic, :string, null: true
      add :fourth_topic, :string, null: true

      timestamps null: false

      # Foreign Keys

      # TODO used in views, but not in indexer
      add :address_id, references(:addresses, on_delete: :delete_all), null: true
      add :receipt_id, references(:receipts, on_delete: :delete_all), null: false
    end

    create index(:logs, :address_id)
    create index(:logs, :index)
    create index(:logs, :type)
    create index(:logs, :first_topic)
    create index(:logs, :second_topic)
    create index(:logs, :third_topic)
    create index(:logs, :fourth_topic)
    create unique_index(:logs, [:receipt_id, :index])
  end
end
