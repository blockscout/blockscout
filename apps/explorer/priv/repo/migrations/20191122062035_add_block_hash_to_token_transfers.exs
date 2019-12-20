defmodule Explorer.Repo.Migrations.AddBlockHashToTokenTransfers do
  use Ecto.Migration

  def change do
    alter table(:token_transfers) do
      add(:block_hash, :bytea)
    end

    execute("""
    UPDATE token_transfers token_transfer
    SET block_hash = with_block.block_hash
    FROM (
      SELECT transfer.transaction_hash,
      t.block_hash
      FROM token_transfers transfer
      JOIN transactions t
      ON t.hash = transfer.transaction_hash
    ) AS with_block
    WHERE token_transfer.transaction_hash = with_block.transaction_hash;
    """)

    execute("""
    DELETE FROM token_transfers WHERE block_hash IS NULL;
    """)

    alter table(:token_transfers) do
      modify(:block_hash, references(:blocks, column: :hash, type: :bytea), null: false)
    end

    execute("""
    ALTER table token_transfers
    DROP CONSTRAINT token_transfers_pkey,
    ADD PRIMARY KEY (transaction_hash, block_hash, log_index);
    """)

    drop(unique_index(:token_transfers, [:transaction_hash, :log_index]))

    create_if_not_exists(index(:token_transfers, [:transaction_hash, :log_index]))
  end
end
