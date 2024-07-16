defmodule Explorer.Repo.Migrations.AddIndexBlocksRefetchNeeded do
  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX consensus_block_hashes_refetch_needed ON blocks(hash) WHERE consensus and refetch_needed;
    """)
  end

  def down do
    execute("""
    DROP INDEX consensus_block_hashes_refetch_needed;
    """)
  end
end
