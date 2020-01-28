-- This script should be a part of migration to "pennding_block_operations" internal transactions indexing approach
-- if 20191018140054_add_pending_internal_txs_operation.exs migration failed due to occasional duplicates of
-- {block_hash, block_index} pair in the DB, that could exist due to bugs in previous versions of the application
--, before setting a primary key on those columns. If so, this script should be inserted at line 57 of that migration
-- just before changing of a primary key.

DO $$
DECLARE
    duplicates_count INTEGER := 0;
    blocks_scanned INTEGER := 0;
    int_txs_count INTEGER := 0;
    temprow RECORD;
BEGIN
    SELECT COUNT(*) INTO int_txs_count FROM internal_transactions;
    IF int_txs_count < 10000000 THEN

        FOR temprow IN
            SELECT block_hash FROM internal_transactions
            GROUP BY block_hash, block_index HAVING COUNT(*) > 1
        LOOP
            duplicates_count := duplicates_count + 1;
            RAISE NOTICE '% duplicates, blocks scanned %, block #%, block hash is %', duplicates_count, blocks_scanned, temprow.number , temprow.hash;

            IF NOT EXISTS (
                SELECT 1 FROM pending_block_operations
                WHERE block_hash = temprow.block_hash
            ) THEN
                INSERT INTO pending_block_operations
                (block_hash, inserted_at, updated_at, fetch_internal_transactions)
                SELECT b.hash, now(), now(), TRUE FROM blocks b
                WHERE b.hash = temprow.block_hash;
            END IF;

            DELETE FROM internal_transactions
            WHERE block_hash = temprow.block_hash;

            RAISE NOTICE 'DELETED';
        END LOOP;

    ELSE
        FOR temprow IN SELECT number, hash FROM blocks LOOP
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
    END IF;
    RAISE NOTICE 'SCRIPT FINISHED';
END $$;