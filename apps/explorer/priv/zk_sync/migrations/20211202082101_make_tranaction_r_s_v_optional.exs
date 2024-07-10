defmodule Explorer.Repo.ZkSync.Migrations.MakeTransactionRSVOptional do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      modify(:r, :numeric, precision: 100, null: true)
    end

    alter table(:transactions) do
      modify(:s, :numeric, precision: 100, null: true)
    end

    alter table(:transactions) do
      modify(:v, :numeric, precision: 100, null: true)
    end
  end
end
