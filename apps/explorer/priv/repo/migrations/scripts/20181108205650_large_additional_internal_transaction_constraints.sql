-- This script is a reimplementation of `20181108205650_additional_internal_transaction_constraints.sql`
-- that is meant to be executed on DBs where the number of transactions and/or
-- internal_transactions is very large.
-- To check the progress it is advised to run this in a `tmux` session or save
-- the output to a file.
-- IMPORTANT NOTE: after making all the corrections needed the script will NOT
-- run the constraint validations because this may be a very long and taxing
-- operation. To validate the constraint one can run, after the script fininshed:

-- ALTER TABLE internal_transactions VALIDATE CONSTRAINT call_has_call_type;
-- ALTER TABLE internal_transactions VALIDATE CONSTRAINT call_has_input;
-- ALTER TABLE internal_transactions VALIDATE CONSTRAINT create_has_init;

DO $$
DECLARE
   batch_size  integer := 10000; -- HOW MANY ITEMS WILL BE UPDATED AT A TIME
   last_transaction_hash bytea; -- WILL CHECK ONLY TRANSACTIONS FOLLOWING THIS HASH (DESC)
   last_fetched_batch_size integer;
BEGIN
  RAISE NOTICE 'STARTING SCRIPT';
  CREATE TEMP TABLE transactions_with_deprecated_internal_transactions(hash bytea NOT NULL);

  LOOP
    RAISE NOTICE 'Fetching new batch of % transactions to correct', batch_size;

    INSERT INTO transactions_with_deprecated_internal_transactions
    SELECT DISTINCT transaction_hash
    FROM internal_transactions
    WHERE
      (last_transaction_hash IS NULL OR transaction_hash < last_transaction_hash) AND
      -- call_has_call_type CONSTRAINT
      ((type = 'call' AND call_type IS NULL) OR
      -- call_has_input CONSTRAINT
      (type = 'call' AND input IS NULL) OR
      -- create_has_init CONSTRAINT
      (type = 'create' AND init is NULL))
    ORDER BY transaction_hash DESC LIMIT batch_size;

    SELECT INTO last_fetched_batch_size count(*) FROM transactions_with_deprecated_internal_transactions;

    RAISE NOTICE 'Batch of % transactions was fetched, starting their deprecation', last_fetched_batch_size;

    -- UPDATE TRANSACTIONS
    UPDATE transactions
    SET internal_transactions_indexed_at = NULL,
        error = NULL
    FROM transactions_with_deprecated_internal_transactions
    WHERE transactions.hash = transactions_with_deprecated_internal_transactions.hash;

    -- REMOVE THE DEPRECATED internal_transactions
    DELETE FROM internal_transactions
    USING transactions_with_deprecated_internal_transactions
    WHERE internal_transactions.transaction_hash = transactions_with_deprecated_internal_transactions.hash;

    -- COMMIT THE BATCH UPDATES
    CHECKPOINT;

    -- UPDATE last_transaction_hash TO KEEP TRACK OF ROWS ALREADY CHECKED
    SELECT INTO last_transaction_hash hash
    FROM transactions_with_deprecated_internal_transactions
    ORDER BY hash ASC LIMIT 1;

    RAISE NOTICE 'Last batch completed, last transaction hash: %', last_transaction_hash;

    -- CLEAR THE TEMP TABLE
    DELETE FROM transactions_with_deprecated_internal_transactions;

    -- EXIT IF ALL internal_transactions HAVE BEEN CHECKED ALREADY
    EXIT WHEN last_fetched_batch_size != batch_size;
  END LOOP;

  RAISE NOTICE 'SCRIPT FINISHED, all affected transactions have been deprecated';

  DROP TABLE transactions_with_deprecated_internal_transactions;
END $$;
