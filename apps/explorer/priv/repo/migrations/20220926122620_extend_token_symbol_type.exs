defmodule Explorer.Repo.Migrations.ExtendTokenSymbolType do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      modify(:symbol, :text, null: true)
    end
  end
end
