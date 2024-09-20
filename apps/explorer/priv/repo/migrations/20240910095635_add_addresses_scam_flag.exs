defmodule Explorer.Repo.Migrations.AddAddressBadgesTables do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add(:is_scam, :boolean)
    end
  end
end
