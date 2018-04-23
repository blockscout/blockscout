defmodule Explorer.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs) do
      add(:data, :text, null: false)
      add(:index, :integer, null: false)
      add(:type, :string, null: false)
      add(:first_topic, :string, null: true)
      add(:second_topic, :string, null: true)
      add(:third_topic, :string, null: true)
      add(:fourth_topic, :string, null: true)

      timestamps(null: false)

      # Foreign Keys

      add(:address_hash, references(:addresses, column: :hash, on_delete: :delete_all, type: :bytea), null: true)
      add(:receipt_id, references(:receipts, on_delete: :delete_all), null: false)
    end

    # Foreign Key indexes

    create(index(:logs, :address_hash))
    create(index(:logs, :receipt_id))

    # Search indexes

    create(index(:logs, :index))
    create(index(:logs, :type))
    create(index(:logs, :first_topic))
    create(index(:logs, :second_topic))
    create(index(:logs, :third_topic))
    create(index(:logs, :fourth_topic))
    create(unique_index(:logs, [:receipt_id, :index]))
  end
end
