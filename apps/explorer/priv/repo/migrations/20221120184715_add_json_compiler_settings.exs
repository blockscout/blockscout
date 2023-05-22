defmodule Explorer.Repo.Migrations.AddJsonCompilerSettings do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:compiler_settings, :jsonb, null: true)
    end
  end
end
