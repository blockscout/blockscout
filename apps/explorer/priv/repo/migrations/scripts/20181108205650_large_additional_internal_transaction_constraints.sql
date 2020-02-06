-- This script is a reimplementation of `20181108205650_additional_internal_transaction_constraints.sql`
-- that is meant to be executed on DBs where the number of transactions and/or
-- internal_transactions is very large.
-- To check the progress it is advised to run this in a `tmux` session or save
-- the output to a file.
-- IMPORTANT NOTE: after making all the corrections needed the script will NOT
-- run the constraint validations because this may be a very long and taxing
-- operation. To validate the constraint one can run, after the script fininshed:
-- UPDATE (2019-11-04): use pending_block_operations table instead of internal_transactions

-- ALTER TABLE internal_transactions VALIDATE CONSTRAINT call_has_call_type;
-- ALTER TABLE internal_transactions VALIDATE CONSTRAINT call_has_input;
-- ALTER TABLE internal_transactions VALIDATE CONSTRAINT create_has_init;

DO $$
DECLARE
   batch_size  integer := 10000; -- HOW MANY ITEMS WILL BE UPDATED AT A TIME
   last_block_number integer; -- WILL CHECK ONLY TRANSACTIONS FOLLOWING THIS HASH (DESC)
   last_fetched_batch_size integer;
BEGIN
  RAISE NOTICE 'STARTING SCRIPT';
  CREATE TEMP TABLE blocks_with_deprecated_internal_transactions(block_number integer NOT NULL);

  LOOP
    RAISE NOTICE 'Fetching new batch of % transactions to correct', batch_size;

    INSERT INTO blocks_with_deprecated_internal_transactions
    SELECT DISTINCT a.block_number
    FROM (
      SELECT DISTINCT i.block_number, i.transaction_index
      FROM internal_transactions i
      WHERE
        i.block_number IS NOT NULL
      AND
        (last_block_number IS NULL OR i.block_number < last_block_number) AND
        -- call_has_call_type CONSTRAINT
        ((i.type = 'call' AND i.call_type IS NULL) OR
        -- call_has_input CONSTRAINT
        (i.type = 'call' AND i.input IS NULL) OR
        -- create_has_init CONSTRAINT
        (i.type = 'create' AND i.init is NULL))
      ORDER BY i.block_number DESC, i.transaction_index LIMIT batch_size
    ) a;

    SELECT INTO last_fetched_batch_size count(block_number) FROM blocks_with_deprecated_internal_transactions;

    RAISE NOTICE 'Batch of % transactions was fetched, starting their deprecation', last_fetched_batch_size;

    INSERT INTO pending_block_operations (block_hash, inserted_at, updated_at, fetch_internal_transactions)
    SELECT b.hash, NOW(), NOW(), true
    FROM blocks_with_deprecated_internal_transactions bd, blocks b
    WHERE bd.block_number = b.number
    AND b.consensus = true
    ON CONFLICT (block_hash) 
    DO NOTHING;

    -- REMOVE THE DEPRECATED internal_transactions
    DELETE FROM internal_transactions
    USING blocks_with_deprecated_internal_transactions
    WHERE internal_transactions.block_number = blocks_with_deprecated_internal_transactions.block_number;

    -- COMMIT THE BATCH UPDATES
    CHECKPOINT;

    -- UPDATE last_block_number TO KEEP TRACK OF ROWS ALREADY CHECKED
    SELECT INTO last_block_number block_number
    FROM blocks_with_deprecated_internal_transactions
    ORDER BY block_number ASC LIMIT 1;

    RAISE NOTICE 'Last batch completed, last block number: %', last_block_number;

    -- CLEAR THE TEMP TABLE
    DELETE FROM blocks_with_deprecated_internal_transactions;

    -- EXIT IF ALL internal_transactions HAVE BEEN CHECKED ALREADY
    EXIT WHEN last_fetched_batch_size != batch_size;
  END LOOP;

  RAISE NOTICE 'SCRIPT FINISHED, all affected transactions have been deprecated';

  DROP TABLE blocks_with_deprecated_internal_transactions;
END $$;
