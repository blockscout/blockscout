DO $$
DECLARE
   row_count integer := 1;
   batch_size  integer := 50000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
   iterator  integer := batch_size;
   affected integer;
BEGIN
  DROP TABLE IF EXISTS transactions_error_itx_indexed_at_temp;

  -- CREATES TEMP TABLE TO STORE TRANSACTIONS TO BE UPDATED
  CREATE TEMP TABLE transactions_error_itx_indexed_at_temp(hash bytea, row_number integer);

  INSERT INTO transactions_error_itx_indexed_at_temp
  SELECT
    DISTINCT it.transaction_hash,
    ROW_NUMBER () OVER ()
  FROM internal_transactions it
  WHERE it.type = 'call'
  AND it.input IS NULL;

  row_count := (SELECT count(*) FROM transactions_error_itx_indexed_at_temp);

  RAISE NOTICE '% items to be updated', row_count;

  -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
  WHILE row_count > 0 LOOP
    -- UPDATES TRANSACTION AND RETURNS THE HASH TO BE DELETED
    WITH updated_transactions AS (
      UPDATE transactions
      SET
        internal_transactions_indexed_at = null,
        error = null
      FROM transactions_error_itx_indexed_at_temp
      WHERE transactions.hash = transactions_error_itx_indexed_at_temp.hash
      AND transactions_error_itx_indexed_at_temp.row_number <= iterator
      RETURNING transactions_error_itx_indexed_at_temp.hash
    )
    -- DELETES THE ITENS UPDATED FROM THE TEMP TABLE
    DELETE FROM transactions_error_itx_indexed_at_temp tt
    USING  updated_transactions uit
    WHERE  tt.hash = uit.hash;

    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE '-> % transactions updated!', affected;

    CHECKPOINT; -- COMMITS THE BATCH UPDATES

    -- UPDATES THE COUNTER SO IT DOESN'T TURN INTO AN INFINITE LOOP
    row_count := (SELECT count(*) FROM transactions_error_itx_indexed_at_temp);
    iterator := iterator + batch_size;

    RAISE NOTICE '-> % counter', row_count;
    RAISE NOTICE '-> % next batch', iterator;
  END LOOP;
END $$;
