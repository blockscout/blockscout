DO $$
DECLARE
   row_count integer := 1;
   batch_size  integer := 50000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
   iterator  integer := batch_size;
   max_row_number integer;
   next_iterator integer;
   updated_transaction_count integer;
   deleted_internal_transaction_count integer;
   deleted_row_count integer;
BEGIN
  DROP TABLE IF EXISTS transactions_with_deprecated_internal_transactions;
  -- CREATES TEMP TABLE TO STORE DATA TO BE UPDATED
  CREATE TEMP TABLE transactions_with_deprecated_internal_transactions(
    hash bytea NOT NULL,
    row_number integer
  );
  INSERT INTO transactions_with_deprecated_internal_transactions
  SELECT DISTINCT ON (transaction_hash)
    transaction_hash,
    ROW_NUMBER () OVER ()
  FROM internal_transactions
  WHERE
    -- call_has_call_type CONSTRAINT
    (type = 'call' AND call_type IS NULL) OR
    -- call_has_input CONSTRAINT
    (type = 'call' AND input IS NULL) OR
    -- create_has_init CONSTRAINT
    (type = 'create' AND init is NULL)
  ORDER BY transaction_hash DESC;

  max_row_number := (SELECT MAX(row_number) FROM transactions_with_deprecated_internal_transactions);
  RAISE NOTICE '% transactions to be updated', max_row_number + 1;

  -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
  WHILE iterator <= max_row_number LOOP
    next_iterator := iterator + batch_size;

    RAISE NOTICE '-> transactions with deprecated internal transactions % to % to be updated', iterator, next_iterator - 1;

    UPDATE transactions
    SET internal_transactions_indexed_at = NULL,
        error = NULL
    FROM transactions_with_deprecated_internal_transactions
    WHERE transactions.hash = transactions_with_deprecated_internal_transactions.hash AND
          transactions_with_deprecated_internal_transactions.row_number < next_iterator;

    GET DIAGNOSTICS updated_transaction_count = ROW_COUNT;

    RAISE NOTICE '-> % transactions updated to refetch internal transactions', updated_transaction_count;

    DELETE FROM internal_transactions
    USING transactions_with_deprecated_internal_transactions
    WHERE internal_transactions.transaction_hash = transactions_with_deprecated_internal_transactions.hash AND
          transactions_with_deprecated_internal_transactions.row_number < next_iterator;

    GET DIAGNOSTICS deleted_internal_transaction_count = ROW_COUNT;

    RAISE NOTICE  '-> % internal transactions deleted', deleted_internal_transaction_count;

    DELETE FROM transactions_with_deprecated_internal_transactions
    WHERE row_number < next_iterator;

    GET DIAGNOSTICS deleted_row_count = ROW_COUNT;

    ASSERT updated_transaction_count = deleted_row_count;

    -- COMMITS THE BATCH UPDATES
    CHECKPOINT;

    -- UPDATES THE COUNTER SO IT DOESN'T TURN INTO AN INFINITE LOOP
    iterator := next_iterator;
  END LOOP;

  RAISE NOTICE 'All deprecated internal transactions will be refetched.  Validating constraints.';

  ALTER TABLE internal_transactions VALIDATE CONSTRAINT call_has_call_type;
  ALTER TABLE internal_transactions VALIDATE CONSTRAINT call_has_input;
  ALTER TABLE internal_transactions VALIDATE CONSTRAINT create_has_init;
END $$;
