defmodule Explorer.Repo.Migrations.CreateIndexForItxType do
  use Ecto.Migration

  def change do
    create(index(:internal_transactions, [:type]))
  end
end
