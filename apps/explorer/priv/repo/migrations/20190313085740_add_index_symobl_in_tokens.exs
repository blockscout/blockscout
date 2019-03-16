defmodule Explorer.Repo.Migrations.AddIndexSymoblInTokens do
  use Ecto.Migration

  def change do
    create(index(:tokens, [:symbol]))
  end
end
