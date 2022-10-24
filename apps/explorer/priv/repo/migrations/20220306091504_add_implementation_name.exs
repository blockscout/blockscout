defmodule Explorer.Repo.Migrations.AddImplementationName do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:implementation_name, :string, null: true)
    end
  end
end
