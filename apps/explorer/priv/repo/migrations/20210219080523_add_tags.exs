defmodule Explorer.Repo.Migrations.AddTags do
  use Ecto.Migration

  def change do
    create table(:address_tags, primary_key: false) do
      add(:id, :serial, null: false)
      add(:label, :string, null: false)

      timestamps()
    end

    create(unique_index(:address_tags, [:id]))
    create(unique_index(:address_tags, [:label]))

    create table(:address_to_tags) do
      add(:address_hash, references(:addresses, column: :hash, type: :bytea), null: false)
      add(:tag_id, references(:address_tags, column: :id, type: :serial), null: false)

      timestamps()
    end

    create(unique_index(:address_to_tags, [:address_hash, :tag_id]))
  end
end
