defmodule Explorer.Repo.Migrations.AddBlockTimestampToTransactionTable do
  use Ecto.Migration

  def change do
    alter table("transactions") do
      add(:block_timestamp, :utc_datetime_usec)
    end

    create(index(:transactions, :block_timestamp))
  end
end
