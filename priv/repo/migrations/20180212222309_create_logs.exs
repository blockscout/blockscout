defmodule Explorer.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs) do
      add :transaction_receipt_id, references(:transaction_receipts), null: false
      add :address_id, references(:addresses), null: false
      add :index, :integer, null: false
      add :data, :string, null: false
      add :removed, :boolean, null: false
      add :first_topic, :string, null: true
      add :second_topic, :string, null: true
      add :third_topic, :string, null: true
      add :fourth_topic, :string, null: true
      timestamps null: false
    end

    create index(:logs, :index)
    create index(:logs, :first_topic)
    create index(:logs, :second_topic)
    create index(:logs, :third_topic)
    create index(:logs, :fourth_topic)
    create index(:logs, :address_id)
    create unique_index(:logs, :transaction_receipt_id)
  end
end
