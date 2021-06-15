-- UPDATE (2020-08-01): use pending_block_operations table
DO $$
DECLARE
   row_count integer := 1;
   batch_size  integer := 500; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
   iterator  integer := batch_size;
   max_row_number integer;
   next_iterator integer;
   updated_blocks_count integer;
   deleted_internal_transaction_count integer;
   deleted_row_count integer;
BEGIN
  DROP TABLE IF EXISTS blocks_with_deprecated_internal_transactions;
  -- CREATES TEMP TABLE TO STORE DATA TO BE UPDATED
  CREATE TEMP TABLE blocks_with_deprecated_internal_transactions(
    block_number integer NOT NULL,
    row_number integer
  );
  INSERT INTO blocks_with_deprecated_internal_transactions
  SELECT DISTINCT ON (a.block_number)
    a.block_number,
    ROW_NUMBER () OVER ()
  FROM (
    SELECT DISTINCT i.block_number, i.transaction_index
    FROM internal_transactions i
    WHERE
      i.block_number IS NOT NULL
    AND
      -- call_has_call_type CONSTRAINT
      ((i.type = 'call' AND i.call_type IS NULL) OR
      -- call_has_input CONSTRAINT
      (i.type = 'call' AND i.input IS NULL) OR
      -- create_has_init CONSTRAINT
      (i.type = 'create' AND i.init is NULL))
    ORDER BY i.block_number DESC, i.transaction_index
  ) a;

  max_row_number := (SELECT MAX(row_number) FROM blocks_with_deprecated_internal_transactions);
  RAISE NOTICE '% blocks to be updated', max_row_number + 1;

  -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
  WHILE iterator <= max_row_number LOOP
    next_iterator := iterator + batch_size;

    RAISE NOTICE '-> blocks with deprecated internal transactions % to % to be updated', iterator, next_iterator - 1;

    INSERT INTO pending_block_operations (block_hash, inserted_at, updated_at, fetch_internal_transactions)
    SELECT b.hash, NOW(), NOW(), true
    FROM blocks_with_deprecated_internal_transactions bd, blocks b
    WHERE bd.block_number = b.number
    AND bd.row_number < next_iterator
    AND b.consensus = true
    ON CONFLICT (block_hash) 
    DO NOTHING;

    GET DIAGNOSTICS updated_blocks_count = ROW_COUNT;

    RAISE NOTICE '-> % blocks updated to refetch internal transactions', updated_blocks_count;

    DELETE FROM internal_transactions
    USING blocks_with_deprecated_internal_transactions
    WHERE internal_transactions.block_number = blocks_with_deprecated_internal_transactions.block_number AND
          blocks_with_deprecated_internal_transactions.row_number < next_iterator;

    GET DIAGNOSTICS deleted_internal_transaction_count = ROW_COUNT;

    RAISE NOTICE  '-> % internal transactions deleted', deleted_internal_transaction_count;

    DELETE FROM blocks_with_deprecated_internal_transactions
    WHERE row_number < next_iterator;

    GET DIAGNOSTICS deleted_row_count = ROW_COUNT;

    ASSERT updated_blocks_count = deleted_row_count;

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
