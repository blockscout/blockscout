defmodule Explorer.Repo.Migrations.AddBridgedTokenCustomCap do
  use Ecto.Migration

  def change do
    alter table(:bridged_tokens) do
      add(:lp_token, :boolean, null: true)
      add(:custom_cap, :decimal, null: true)
    end
  end
end
