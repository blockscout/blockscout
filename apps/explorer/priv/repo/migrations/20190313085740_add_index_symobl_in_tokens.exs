defmodule Explorer.Repo.Migrations.AddIndexSymbolInTokens do
  use Ecto.Migration

  def change do
    create(index(:tokens, [:symbol]))
  end
end
