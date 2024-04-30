defmodule Explorer.Repo.Migrations.AddVolume24hToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:volume_24h, :decimal)
    end
  end
end
