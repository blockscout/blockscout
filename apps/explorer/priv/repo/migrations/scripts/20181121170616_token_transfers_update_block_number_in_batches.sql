DO $$
DECLARE
   row_count integer;
   batch_size  integer := 100000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
   affected integer;
BEGIN
  RAISE NOTICE 'Counting items to be updated';

  row_count := (SELECT COUNT(*) FROM token_transfers WHERE block_number IS NULL);

  RAISE NOTICE '% items', row_count;

  WHILE row_count > 0 LOOP
    WITH cte AS (
     SELECT
       t.hash,
       t.block_number
     FROM token_transfers AS tt
     INNER JOIN transactions AS t ON t.hash = tt.transaction_hash
	   WHERE tt.block_number IS NULL
     LIMIT batch_size
    )
    UPDATE token_transfers
    SET
      block_number = cte.block_number
    FROM cte
    WHERE token_transfers.transaction_hash = cte.hash;

    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE '-> % token transfers updated!', affected;

    -- UPDATES THE COUNTER SO IT DOESN'T TURN INTO AN INFINITE LOOP
    row_count := row_count - batch_size;

    RAISE NOTICE '-> % items missing to update', row_count;

    CHECKPOINT; -- COMMITS THE BATCH UPDATES
  END LOOP;
END $$;
