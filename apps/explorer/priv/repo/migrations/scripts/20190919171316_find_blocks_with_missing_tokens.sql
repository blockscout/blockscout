-- This script finds all the block numbers with missing token transfers in a given
-- range and puts them into a table (blocks_to_invalidate_missing_tt)
-- To check the progress it is advised to run this in a `tmux` session or save
-- the output to a file.

DO $$
DECLARE
  batch_size  integer := 1000; -- HOW MANY ITEMS WILL BE UPDATED AT A TIME
  max_number_to_check bigint; -- WILL CHECK ONLY TRANSACTIONS FOLLOWING THIS HASH (DESC)
  min_number_to_check bigint; -- WILL CHECK ONLY TRANSACTIONS FOLLOWING THIS HASH (DESC)
  min_batch_number bigint;
BEGIN
  RAISE NOTICE 'STARTING SCRIPT';
  CREATE TABLE IF NOT EXISTS blocks_to_invalidate_missing_tt(block_number bigint, refetched boolean);

  -- IF max_number_to_check IS NOT SET IT WILL RESUME FROM THE LAST RUN
  IF max_number_to_check IS NULL THEN
    SELECT INTO max_number_to_check block_number
    FROM blocks_to_invalidate_missing_tt
    ORDER BY block_number ASC LIMIT 1;
  END IF;

  -- IF THERE WAS NO LAST RUN AND max_number_to_check IS NOT SET THEN IT WILL BE THE HIGHEST block number
  IF max_number_to_check IS NULL THEN
    SELECT INTO max_number_to_check number
    FROM blocks
    ORDER BY number DESC LIMIT 1;
  END IF;

  -- IF min_number_to_check IS NOT SET IT IS SET TO BE 0
  IF min_number_to_check IS NULL THEN
    SELECT INTO min_number_to_check 0;
  END IF;

  RAISE NOTICE 'Starting first batch from % (DESC)', max_number_to_check;

  LOOP
    RAISE NOTICE 'Checking new batch of % block numbers', batch_size;

    -- UPDATE min_batch_number
    SELECT INTO min_batch_number GREATEST(max_number_to_check - batch_size + 1, min_number_to_check);

    INSERT INTO blocks_to_invalidate_missing_tt
    SELECT * FROM generate_series(max_number_to_check, min_batch_number, -1) AS s (block_number)
    WHERE EXISTS(
      SELECT 1 FROM transactions t
      WHERE t.block_number = s.block_number
      AND NOT EXISTS (
        SELECT 1 FROM token_transfers tt
        WHERE tt.transaction_hash = t.hash
        )
      AND (
        EXISTS (
          SELECT 1 FROM internal_transactions i
          WHERE i.transaction_hash = t.hash
          AND encode(i.input::bytea, 'hex') LIKE 'a9059%'
          AND i.error IS NULL
          )
        OR EXISTS (
          SELECT 1 FROM logs l
          WHERE l.transaction_hash = t.hash
          AND l.first_topic LIKE '0xddf252ad%'
          AND (
            (l.second_topic IS NOT NULL AND l.third_topic IS NOT NULL)
            OR
            (l.second_topic IS NULL AND l.third_topic IS NULL)
            )
          )
        )
      )
    ;

    -- COMMIT THE BATCH
    CHECKPOINT;
    RAISE NOTICE 'Last batch completed, last block number checked: %', min_batch_number;

    -- EXIT IF ALL blocks HAVE BEEN CHECKED ALREADY
    EXIT WHEN min_batch_number = min_number_to_check;

    -- UPDATE max_number_to_check TO START THE NEXT BATCH
    SELECT INTO max_number_to_check (min_batch_number - 1);
  END LOOP;

  RAISE NOTICE 'SCRIPT FINISHED, all affected block numbers have been inseted into table: blocks_to_invalidate_missing_tt';
END $$;
