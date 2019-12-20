defmodule Explorer.Repo.Migrations.AddPendingInternalTxsOperation do
  use Ecto.Migration

  def change do
    alter table(:pending_block_operations) do
      add(:fetch_internal_transactions, :boolean, null: false)
    end

    execute("""
    INSERT INTO pending_block_operations
    (block_hash, inserted_at, updated_at, fetch_internal_transactions)
    SELECT b.hash, now(), now(), TRUE FROM blocks b
    WHERE b.internal_transactions_indexed_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM transactions t
      WHERE b.hash = t.block_hash
      AND t.internal_transactions_indexed_at IS NULL
    );
    """)

    alter table(:blocks) do
      remove(:internal_transactions_indexed_at)
    end

    alter table(:transactions) do
      remove(:internal_transactions_indexed_at)
    end

    alter table(:internal_transactions) do
      add(:block_hash, :bytea)
      add(:block_index, :integer)
    end

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
    AND itx.index = with_block.index;
    """)

    execute("""
    DELETE FROM internal_transactions WHERE block_hash IS NULL;
    """)

    execute("""
    DO $$
    DECLARE
        duplicates_count INTEGER := 0;
        blocks_scanned INTEGER := 0;
        temprow RECORD;
    BEGIN
        FOR temprow IN
            SELECT number, hash FROM blocks
        LOOP
            blocks_scanned := blocks_scanned + 1;
            IF EXISTS (
                SELECT 1 FROM transactions WHERE block_hash = temprow.hash
            ) THEN
                IF EXISTS (
                    SELECT block_hash, block_index FROM internal_transactions
                    WHERE block_hash = temprow.hash
                    GROUP BY block_hash, block_index HAVING COUNT(*) > 1
                ) THEN
                    duplicates_count := duplicates_count + 1;
                    RAISE NOTICE '% duplicates, blocks scanned %, block #%, block hash is %', duplicates_count, blocks_scanned, temprow.number , temprow.hash;

                    IF NOT EXISTS (
                        SELECT 1 FROM pending_block_operations
                        WHERE block_hash = temprow.hash
                    ) THEN
                        INSERT INTO pending_block_operations
                        (block_hash, inserted_at, updated_at, fetch_internal_transactions)
                        SELECT b.hash, now(), now(), TRUE FROM blocks b
                        WHERE b.hash = temprow.hash;
                    END IF;

                    DELETE FROM internal_transactions
                    WHERE block_hash = temprow.hash;

                    RAISE NOTICE 'DELETED';
                END IF;
            END IF;
        END LOOP;
        RAISE NOTICE 'SCRIPT FINISHED';
    END $$;
    """)

    execute("""
    ALTER table internal_transactions
    DROP CONSTRAINT internal_transactions_pkey,
    ADD PRIMARY KEY (block_hash, block_index);
    """)

    alter table(:internal_transactions) do
      modify(:block_hash, references(:blocks, column: :hash, type: :bytea), null: false)
      modify(:block_index, :integer, null: false)
    end

    drop(
      index(
        :internal_transactions,
        [:transaction_hash, :index],
        name: :internal_transactions_transaction_hash_index_index
      )
    )

    create_if_not_exists(index(:internal_transactions, [:transaction_hash, :index]))
  end
end
