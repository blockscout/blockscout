defmodule Explorer.Repo.PolygonZkevm.Migrations.MakeTimestampOptional do
  use Ecto.Migration

  def change do
    alter table("polygon_zkevm_transaction_batches") do
      modify(:timestamp, :"timestamp without time zone", null: true)
    end
  end
end
