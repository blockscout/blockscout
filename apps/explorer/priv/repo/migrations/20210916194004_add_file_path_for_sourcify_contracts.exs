defmodule Explorer.Repo.Migrations.AddFilePathForSourcifyContracts do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:file_path, :text, null: true)
    end
  end
end
