defmodule Explorer.Repo.Migrations.AddBlockHashAndBlockIndexToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:block_hash, :bytea)
      add(:block_number, :integer)
    end

    execute("""
    UPDATE logs log
    SET block_hash = with_block.block_hash,
    block_number = with_block.block_number
    FROM (
      SELECT l.transaction_hash,
      t.block_hash,
      t.block_number
      FROM logs l
      JOIN transactions t
      ON t.hash = l.transaction_hash
    ) AS with_block
    WHERE log.transaction_hash = with_block.transaction_hash;
    """)

    execute("""
    DELETE FROM logs WHERE block_hash IS NULL;
    """)

    alter table(:logs) do
      modify(:block_hash, references(:blocks, column: :hash, type: :bytea), null: false)
    end

    execute("""
    ALTER table logs
    DROP CONSTRAINT logs_pkey,
    ADD PRIMARY KEY (transaction_hash, block_hash, index);
    """)

    drop(unique_index(:logs, [:transaction_hash, :index]))

    create_if_not_exists(index(:logs, [:transaction_hash, :index]))
  end
end
