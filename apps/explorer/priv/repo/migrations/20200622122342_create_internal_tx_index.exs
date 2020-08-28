defmodule Explorer.Repo.Migrations.CreateInternalTxIndex do
  use Ecto.Migration

  def change do
    create(index(:internal_transactions, [:value, :call_type, :index]))
  end
end
