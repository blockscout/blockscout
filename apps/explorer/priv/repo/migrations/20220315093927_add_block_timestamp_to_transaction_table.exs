defmodule Explorer.Repo.Migrations.AddBlockTimestampToTransactionTable do
  use Ecto.Migration

  def change do
    alter table("transactions") do
      add(:block_timestamp, :utc_datetime_usec)
    end

    execute("""
    UPDATE transactions tx
    SET block_timestamp = b.timestamp
    FROM blocks b
    WHERE b.hash = tx.block_hash;
    """)

    create(index(:transactions, :block_timestamp))
  end
end
