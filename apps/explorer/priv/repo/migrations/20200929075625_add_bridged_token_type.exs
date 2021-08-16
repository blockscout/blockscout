defmodule Explorer.Repo.Migrations.AddBridgedTokenType do
  use Ecto.Migration

  def change do
    alter table(:bridged_tokens) do
      add(:type, :string, null: true)
    end
  end
end
