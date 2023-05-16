defmodule Explorer.Repo.Migrations.AddTokenIconUrl do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:icon_url, :string, null: true)
    end
  end
end
