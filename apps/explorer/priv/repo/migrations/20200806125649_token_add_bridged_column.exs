defmodule Explorer.Repo.Migrations.TokenAddBridgedColumn do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:bridged, :boolean, null: true)
    end
  end
end
