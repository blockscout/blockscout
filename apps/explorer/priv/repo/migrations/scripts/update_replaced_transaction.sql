DO $$
  DECLARE
    total_count         integer                     := 0;
    completed_count     integer                     := 0;
    remaining_count     integer                     := 0;
    batch_size          integer                     := 50;
    iterator            integer                     := batch_size;
    updated_count       integer;
    deleted_count       integer;
    start_time          TIMESTAMP WITHOUT TIME ZONE := clock_timestamp();
    end_time            TIMESTAMP WITHOUT TIME ZONE;
    elapsed_time        INTERVAL;
    temp_start_time     TIMESTAMP WITHOUT TIME ZONE;
    temp_end_time       TIMESTAMP WITHOUT TIME ZONE;
    temp_elapsed_time   INTERVAL;
    update_start_time   TIMESTAMP WITHOUT TIME ZONE;
    update_end_time     TIMESTAMP WITHOUT TIME ZONE;
    update_elapsed_time INTERVAL;
    per_row             INTERVAL;
  BEGIN
    RAISE NOTICE 'Started at %', start_time;

    temp_start_time := clock_timestamp();

    DROP TABLE IF EXISTS transactions_dropped_replaced;
    CREATE TEMP TABLE transactions_dropped_replaced
    (
      nonce integer NOT NULL,
      from_address_hash bytea NOT NULL,
      row_number integer NOT NULL
    );

    INSERT INTO transactions_dropped_replaced
    SELECT t1.nonce,
           t1.from_address_hash,
           ROW_NUMBER() OVER ()
    FROM transactions t1
      INNER JOIN transactions t2
      ON t1.from_address_hash = t2.from_address_hash AND t1.nonce = t2.nonce AND t2.block_hash IS NOT NULL
    WHERE t1.block_hash IS NULL;

    temp_end_time := clock_timestamp();
    temp_elapsed_time := temp_end_time - temp_start_time;
    total_count := (SELECT COUNT(*) FROM transactions_dropped_replaced);

    RAISE NOTICE 'transactions_dropped_replaced TEMP table filled in %', temp_elapsed_time;

    remaining_count := total_count;

    RAISE NOTICE '% transactions to be updated', remaining_count;

    update_start_time := clock_timestamp();

    WHILE remaining_count > 0
      LOOP
        UPDATE transactions
        SET error = 'dropped/replaced', status = 0
        FROM transactions_dropped_replaced
        WHERE transactions_dropped_replaced.row_number <= iterator AND
              transactions_dropped_replaced.nonce = transactions.nonce AND
              transactions_dropped_replaced.from_address_hash = transactions.from_address_hash AND
              transactions.block_hash IS NULL;

        GET DIAGNOSTICS updated_count = ROW_COUNT;
        RAISE NOTICE '-> % transaction counts updated.', updated_count;

        DELETE
        FROM transactions_dropped_replaced
        WHERE transactions_dropped_replaced.row_number <= iterator;

        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE '-> % transactions from it count removed from queue.', deleted_count;

        -- COMMITS THE BATCH UPDATES
        CHECKPOINT;

        remaining_count := remaining_count - deleted_count;
        iterator := iterator + batch_size;
        RAISE NOTICE '-> % remaining', remaining_count;
        RAISE NOTICE '-> % next batch', iterator;
        update_elapsed_time := clock_timestamp() - update_start_time;
        completed_count := total_count - remaining_count;
        per_row := update_elapsed_time / completed_count;
        RAISE NOTICE '-> Estimated time until completion: %s', per_row * remaining_count;
      END LOOP;

    end_time := clock_timestamp();
    elapsed_time := end_time - start_time;

    RAISE NOTICE 'Ended at %s', end_time;
    RAISE NOTICE 'Elapsed time: %', elapsed_time;
END $$;
