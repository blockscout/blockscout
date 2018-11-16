DO $$
DECLARE
   row_count integer := 1;
   batch_size  integer := 50000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
   iterator  integer := batch_size;
   affected integer;
BEGIN
  DROP TABLE IF EXISTS current_suicide_internal_transactions_temp;
  -- CREATES TEMP TABLE TO STORE TOKEN BALANCES TO BE UPDATED
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

  row_count := (SELECT count(*) FROM current_suicide_internal_transactions_temp);
  RAISE NOTICE '% items to be updated', row_count;

  -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
  WHILE row_count > 0 LOOP
    -- UPDATES THE INTERNAL TRANSACTION AND RETURNS THE ADDRESS HASH AND TOKEN HASH TO BE DELETED
    WITH updated_internal_transactions AS (
      UPDATE internal_transactions
      SET type = "suicide"
      FROM current_suicide_internal_transactions_temp
      WHERE internal_transactions.transaction_hash = current_suicide_internal_transactions_temp.transaction_hash AND
            internal_transactions.index = current_suicide_internal_transactions_temp.index AND
            current_suicide_internal_transactions_temp.row_number <= iterator
      RETURNING current_suicide_internal_transactions_temp.row_number
    )
    DELETE FROM current_suicide_internal_transactions_temp
    WHERE row_number IN (select row_number from updated_address_current_token_balances);

    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE '-> % address current token balances updated!', affected;

    -- COMMITS THE BATCH UPDATES
    CHECKPOINT;

    -- UPDATES THE COUNTER SO IT DOESN'T TURN INTO AN INFINITE LOOP
    row_count := (SELECT count(*) FROM current_token_balance_temp);
    iterator := iterator + batch_size;
    RAISE NOTICE '-> % counter', row_count;
    RAISE NOTICE '-> % next batch', iterator;
  END LOOP;

  RAISE NOTICE 'All suicide type internal transactions updated to selfdestruct.  Validating constraint.';

  ALTER TABLE internal_transactions VALIDATE CONSTRAINT selfdestruct_has_from_and_to_address;
END $$;
