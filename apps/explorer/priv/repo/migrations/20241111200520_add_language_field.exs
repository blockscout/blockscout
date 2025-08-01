defmodule Explorer.Repo.Migrations.AddLanguageField do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:language, :int2, null: true)
    end
  end
end
