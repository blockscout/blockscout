DO $$
  DECLARE
    total_count         integer                     := 0;
    batch_size          integer                     := 1000;
    update_count        integer;
    update_count_batch  integer;
    cursor_count        integer;
    cursor_count_batch  integer;
    row_count           integer;
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
    tx_drop_repl_curs   CURSOR FOR SELECT * FROM transactions_dropped_replaced;
  BEGIN
    RAISE NOTICE 'Started at %', start_time;

    temp_start_time := clock_timestamp();

    DROP TABLE IF EXISTS transactions_dropped_replaced;
    CREATE TEMP TABLE transactions_dropped_replaced
    (
      nonce integer NOT NULL,
      from_address_hash bytea NOT NULL,
      row_number integer NOT NULL,
      PRIMARY KEY (nonce, from_address_hash)
    );

    INSERT INTO transactions_dropped_replaced
    SELECT t1.nonce,
           t1.from_address_hash,
           ROW_NUMBER() OVER ()
    FROM transactions t1
    WHERE t1.block_hash IS NULL AND
          t1.error IS NULL AND
          EXISTS (SELECT *
                  FROM transactions t2
                  WHERE t2.nonce = t1.nonce AND
                        t2.from_address_hash = t1.from_address_hash AND
                        t2.block_hash IS NOT NULL)
    GROUP BY t1.nonce, t1.from_address_hash;

    temp_end_time := clock_timestamp();
    temp_elapsed_time := temp_end_time - temp_start_time;
    total_count := (SELECT COUNT(*) FROM transactions_dropped_replaced);

    RAISE NOTICE 'transactions_dropped_replaced TEMP table filled in %', temp_elapsed_time;

    RAISE NOTICE '% transactions to be updated', total_count;

    update_start_time := clock_timestamp();

    cursor_count       := 0;
    update_count       := 0;
    cursor_count_batch := 0;
    update_count_batch := 0;

    <<XX>>
    FOR rec IN tx_drop_repl_curs
      LOOP
        cursor_count       := cursor_count       + 1;
        cursor_count_batch := cursor_count_batch + 1;

        UPDATE transactions
        SET error = 'dropped/replaced', status = 0
        WHERE nonce = rec.nonce AND
            from_address_hash = rec.from_address_hash AND
            block_hash IS NULL AND
            error IS NULL;

        GET DIAGNOSTICS row_count = ROW_COUNT;
        update_count       := update_count       + row_count;
        update_count_batch := update_count_batch + row_count;

        CONTINUE WHEN cursor_count < total_count AND cursor_count % batch_size != 0;

        RAISE NOTICE '-> % transaction counts updated.', update_count_batch;
        update_count_batch := 0;

        RAISE NOTICE '-> % transactions from it count removed from queue.', cursor_count_batch;
        cursor_count_batch := 0;

        RAISE NOTICE '-> % remaining', total_count - cursor_count;
        RAISE NOTICE '-> % next batch', cursor_count;
        update_elapsed_time := clock_timestamp() - update_start_time;
        per_row := update_elapsed_time / cursor_count;
        RAISE NOTICE '-> Estimated time until completion: %s', per_row * (total_count - cursor_count);
      END LOOP XX;

    end_time := clock_timestamp();
    elapsed_time := end_time - start_time;

    RAISE NOTICE 'Ended at %s', end_time;
    RAISE NOTICE 'Elapsed time: %', elapsed_time;
END $$;
