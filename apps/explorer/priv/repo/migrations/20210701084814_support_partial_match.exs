defmodule Explorer.Repo.Migrations.SupportPartialMatch do
  use Ecto.Migration

  def change do
    alter table(:smart_contracts) do
      add(:partially_verified, :boolean, null: true)
    end
  end
end
