DO $$
  DECLARE
    total_count         integer                     := 0;
    completed_count     integer                     := 0;
    remaining_count     integer                     := 0;
    -- Eth Mainnet has ~80000 tokens and the old ETs way took ~90 minutes so approximate 1000 tokens per minute and
    -- make each batch take approximately 1 minute
    batch_size          integer                     := 1000;
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

    DROP TABLE IF EXISTS tokens_without_holder_count;
    CREATE TEMP TABLE tokens_without_holder_count
    (
      contract_address_hash bytea NOT NULL,
      row_number integer NOT NULL
    );

    INSERT INTO tokens_without_holder_count
    SELECT tokens.contract_address_hash,
           ROW_NUMBER() OVER ()
    FROM tokens
    WHERE tokens.holder_count IS NULL;

    temp_end_time := clock_timestamp();
    temp_elapsed_time := temp_end_time - temp_start_time;
    total_count := (SELECT COUNT(*) FROM tokens_without_holder_count);

    RAISE NOTICE 'tokens_without_holder_count TEMP table filled in %', temp_elapsed_time;

    remaining_count := total_count;

    RAISE NOTICE '% tokens to be updated', remaining_count;

    update_start_time := clock_timestamp();

    WHILE remaining_count > 0
      LOOP
        UPDATE tokens
        SET holder_count = (
                SELECT COUNT(*)
                FROM address_current_token_balances
                WHERE address_current_token_balances.token_contract_address_hash = tokens.contract_address_hash AND
                      address_current_token_balances.address_hash != '\x0000000000000000000000000000000000000000' AND
                      address_current_token_balances.value > 0
              )
        FROM tokens_without_holder_count
        WHERE tokens_without_holder_count.row_number <= iterator AND
              tokens_without_holder_count.contract_address_hash = tokens.contract_address_hash AND
              tokens.holder_count IS NULL;

        GET DIAGNOSTICS updated_count = ROW_COUNT;
        RAISE NOTICE '-> % token holder counts updated.', updated_count;

        DELETE
        FROM tokens_without_holder_count
        WHERE tokens_without_holder_count.row_number <= iterator;

        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE '-> % tokens without holder count removed from queue.', deleted_count;

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
