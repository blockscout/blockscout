defmodule Explorer.Repo.Migrations.UpdateInternalTransactionsFillBlockHashBlockIndex do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE internal_transactions itx
    SET block_hash = with_block.block_hash, block_index = with_block.block_index
    FROM (
      SELECT i.transaction_hash,
      i.index,
      t.block_hash,
      row_number() OVER(
        PARTITION BY t.block_hash
        ORDER BY i.transaction_hash, i.index
      ) - 1 AS block_index
      FROM internal_transactions i
      JOIN transactions t
      ON t.hash = i.transaction_hash
    ) AS with_block
    WHERE itx.transaction_hash = with_block.transaction_hash
    AND itx.index = with_block.index
    ;
    """)
  end
end
