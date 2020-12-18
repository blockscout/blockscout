defmodule Explorer.Repo.Migrations.InternalTxsAllowNilType do
  use Ecto.Migration

  def up do
    alter table(:internal_transactions) do
      modify(:type, :string, null: true)
    end
  end

  def down do
    alter table(:internal_transactions) do
      modify(:type, :string, null: false)
    end
  end
end
