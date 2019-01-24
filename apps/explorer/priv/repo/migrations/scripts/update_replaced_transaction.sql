DO $$
  DECLARE
    start_time          TIMESTAMP WITHOUT TIME ZONE := clock_timestamp();
    end_time            TIMESTAMP WITHOUT TIME ZONE;
    elapsed_time        INTERVAL;
    temp_start_time     TIMESTAMP WITHOUT TIME ZONE;
    temp_end_time       TIMESTAMP WITHOUT TIME ZONE;
  BEGIN
    RAISE NOTICE 'Started at %', start_time;

    temp_start_time := clock_timestamp();

    UPDATE transactions SET error = 'dropped/replaced', status = 0 FROM transactions t1
    INNER JOIN transactions t2
    ON t1.from_address_hash = t2.from_address_hash AND t1.nonce = t2.nonce
    WHERE t1.block_hash IS NULL AND t2.block_hash IS NOT NULL;

    end_time := clock_timestamp();
    elapsed_time := end_time - start_time;

    RAISE NOTICE 'Ended at %s', end_time;
    RAISE NOTICE 'Elapsed time: %', elapsed_time;
END $$;
