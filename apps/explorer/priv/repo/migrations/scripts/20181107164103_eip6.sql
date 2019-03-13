DO $$
DECLARE
   row_count integer := 1;
   batch_size  integer := 50000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
   iterator  integer := batch_size;
   max_row_number integer;
   next_iterator integer;
   updated_row_count integer;
   deleted_row_count integer;
BEGIN
  DROP TABLE IF EXISTS current_suicide_internal_transactions_temp;
  -- CREATES TEMP TABLE TO STORE DATA TO BE UPDATED
  CREATE TEMP TABLE current_suicide_internal_transactions_temp(
    transaction_hash bytea NOT NULL,
    index bigint NOT NULL,
    row_number integer
  );
  INSERT INTO current_suicide_internal_transactions_temp
  SELECT DISTINCT ON (transaction_hash, index)
    transaction_hash,
    index,
    ROW_NUMBER () OVER ()
  FROM internal_transactions
  WHERE type = 'suicide'
  ORDER BY transaction_hash, index DESC;

  max_row_number := (SELECT MAX(row_number) FROM current_suicide_internal_transactions_temp);
  RAISE NOTICE '% items to be updated', max_row_number + 1;

  -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
  WHILE iterator <= max_row_number LOOP
    next_iterator := iterator + batch_size;

    RAISE NOTICE '-> suicide internal transactions % to % to be updated', iterator, next_iterator - 1;

    UPDATE internal_transactions
    SET type = 'selfdestruct'
    FROM current_suicide_internal_transactions_temp
    WHERE internal_transactions.transaction_hash = current_suicide_internal_transactions_temp.transaction_hash AND
          internal_transactions.index = current_suicide_internal_transactions_temp.index AND
          current_suicide_internal_transactions_temp.row_number < next_iterator;

    GET DIAGNOSTICS updated_row_count = ROW_COUNT;

    RAISE NOTICE '-> % internal transactions updated from suicide to selfdesruct', updated_row_count;

    DELETE FROM current_suicide_internal_transactions_temp
    WHERE row_number < next_iterator;

    GET DIAGNOSTICS deleted_row_count = ROW_COUNT;

    ASSERT updated_row_count = deleted_row_count;

    -- COMMITS THE BATCH UPDATES
    CHECKPOINT;

    -- UPDATES THE COUNTER SO IT DOESN'T TURN INTO AN INFINITE LOOP
    iterator := next_iterator;
  END LOOP;

  RAISE NOTICE 'All suicide type internal transactions updated to selfdestruct.  Validating constraint.';

  ALTER TABLE internal_transactions VALIDATE CONSTRAINT selfdestruct_has_from_and_to_address;
END $$;
