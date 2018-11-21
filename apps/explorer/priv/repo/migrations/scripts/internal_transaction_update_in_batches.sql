DO $$
DECLARE
   row_count integer := 1;
   batch_size  integer := 50000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
   iterator  integer := batch_size;
   affected integer;
BEGIN
  DROP TABLE IF EXISTS transactions_temp;

  -- CREATES TEMP TABLE TO STORE TRANSACTIONS TO BE UPDATED
  CREATE TEMP TABLE transactions_temp(hash bytea, block_number integer, index integer, row_number integer);
  INSERT INTO transactions_temp
  SELECT
    t.hash,
    t.block_number,
    t.index,
    ROW_NUMBER () OVER ()
  FROM transactions t
  INNER JOIN internal_transactions it ON t.hash = it.transaction_hash AND it.block_number IS NULL
  WHERE
    t.hash = it.transaction_hash
    AND it.block_number IS NULL
  ;

  row_count := (SELECT count(*) FROM transactions_temp);

  RAISE NOTICE '% items to be updated', row_count;

  -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
  WHILE row_count > 0 LOOP
    -- UPDATES INTERNAL TRANSACTION AND RETURNS THE HASH TO BE DELETED
    WITH updated_internal_transactions AS (
      UPDATE internal_transactions
      SET
        block_number = transactions_temp.block_number,
        transaction_index = transactions_temp.index
      FROM transactions_temp
      WHERE internal_transactions.transaction_hash = transactions_temp.hash
      AND transactions_temp.row_number <= iterator
      RETURNING transactions_temp.hash
    )
    -- DELETES THE ITENS UPDATED FROM THE TEMP TABLE
    DELETE FROM transactions_temp tt
    USING  updated_internal_transactions uit
    WHERE  tt.hash = uit.hash;

    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE '-> % internal transactions updated!', affected;

    CHECKPOINT; -- COMMITS THE BATCH UPDATES

    -- UPDATES THE COUNTER SO IT DOESN'T TURN INTO AN INFINITE LOOP
    row_count := (SELECT count(*) FROM transactions_temp);
    iterator := iterator + batch_size;

    RAISE NOTICE '-> % counter', row_count;
    RAISE NOTICE '-> % next batch', iterator;
  END LOOP;
END $$;
