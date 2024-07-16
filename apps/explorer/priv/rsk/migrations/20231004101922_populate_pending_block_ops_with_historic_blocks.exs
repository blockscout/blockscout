defmodule Explorer.Repo.RSK.Migrations.PopulatePendingBlockOpsWithHistoricBlocks do
  use Ecto.Migration

  def change do
    execute("""
      INSERT INTO pending_block_operations
      SELECT b.hash, NOW(), NOW(), b.number
      FROM blocks b
              LEFT JOIN pending_block_operations pbo
                        ON b.hash = pbo.block_hash
      WHERE consensus IS TRUE
        and b.hash IS NOT NULL
        and pbo.block_hash IS NULL;
    """)
  end
end
