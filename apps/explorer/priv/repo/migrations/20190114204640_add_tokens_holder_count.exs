defmodule Explorer.Repo.Migrations.AddTokensHolderCount do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      # `NULL` so it can be filled in in the background while upgrading
      add(:holder_count, :integer, null: true)
    end
  end
end
