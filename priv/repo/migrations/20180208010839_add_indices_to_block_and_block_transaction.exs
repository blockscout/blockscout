defmodule Explorer.Repo.Migrations.AddIndicesToBlockAndBlockTransaction do
  use Ecto.Migration

  def change do
    create index(:block_transactions, :block_id)
    create index(:blocks, :timestamp)
  end
end
