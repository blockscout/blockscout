defmodule Explorer.Repo.Migrations.AddBlockHashAndBlockIndexToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:block_hash, :bytea)
    end

    execute("""
    UPDATE logs log
    SET block_hash = with_block.block_hash
    FROM (
      SELECT l.transaction_hash,
      t.block_hash
      FROM logs l
      JOIN transactions t
      ON t.hash = l.transaction_hash
    ) AS with_block
    WHERE log.transaction_hash = with_block.transaction_hash
    ;
    """)

    alter table(:logs) do
      modify(:block_hash, references(:blocks, column: :hash, type: :bytea), null: false)
    end

    execute("""
    ALTER table logs
    DROP CONSTRAINT logs_pkey,
    ADD PRIMARY KEY (transaction_hash, block_hash, index);
    """)
  end
end
