DO $$
  DECLARE
    total_count         integer                     := 0;
    completed_count     integer                     := 0;
    remaining_count     integer                     := 0;
    batch_size          integer                     := 50000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
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

    DROP TABLE IF EXISTS correct_address_current_token_block_numbers;
    CREATE TEMP TABLE correct_address_current_token_block_numbers
    (
      address_hash                bytea  NOT NULL,
      token_contract_address_hash bytea  NOT NULL,
      block_number                bigint NOT NULL,
      row_number                  integer
    );
    INSERT INTO correct_address_current_token_block_numbers
    SELECT address_token_balances.address_hash,
           address_token_balances.token_contract_address_hash,
           MAX(address_token_balances.block_number),
           ROW_NUMBER() OVER ()
    FROM address_token_balances
           INNER JOIN address_current_token_balances
                      ON address_current_token_balances.address_hash =
                         address_token_balances.address_hash AND
                         address_current_token_balances.token_contract_address_hash =
                         address_token_balances.token_contract_address_hash
    GROUP BY address_token_balances.address_hash,
             address_token_balances.token_contract_address_hash,
             address_current_token_balances.block_number
    HAVING MAX(address_token_balances.block_number) != address_current_token_balances.block_number;

    temp_end_time := clock_timestamp();
    temp_elapsed_time := temp_end_time - temp_start_time;
    total_count := (SELECT COUNT(*) FROM correct_address_current_token_block_numbers);

    RAISE NOTICE 'correct_address_current_token_block_numbers TEMP table filled in %', temp_elapsed_time;

    remaining_count := total_count;

    RAISE NOTICE '% address_current_token_balances to be updated', remaining_count;

    update_start_time := clock_timestamp();

    -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
    WHILE remaining_count > 0
      LOOP
        UPDATE address_current_token_balances
        SET block_number = correct_address_current_token_block_numbers.block_number,
            value        = address_token_balances.value,
            updated_at   = NOW()
        FROM correct_address_current_token_block_numbers,
             address_token_balances
        WHERE correct_address_current_token_block_numbers.row_number <= iterator
          AND
            correct_address_current_token_block_numbers.address_hash = address_current_token_balances.address_hash
          AND
            correct_address_current_token_block_numbers.token_contract_address_hash =
            address_current_token_balances.token_contract_address_hash
          AND
            address_current_token_balances.block_number < correct_address_current_token_block_numbers.block_number
          AND
            address_token_balances.address_hash = address_current_token_balances.address_hash
          AND
            address_token_balances.token_contract_address_hash =
            address_current_token_balances.token_contract_address_hash
          AND
            address_token_balances.block_number = correct_address_current_token_block_numbers.block_number;

        GET DIAGNOSTICS updated_count = ROW_COUNT;
        RAISE NOTICE '-> % address current token balances updated.', updated_count;

        DELETE
        FROM correct_address_current_token_block_numbers
        WHERE correct_address_current_token_block_numbers.row_number <= iterator;

        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE '-> % address tokens block numbers removed from queue.', deleted_count;

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
    update_end_time := end_time;
    update_elapsed_time = update_end_time - update_start_time;

    IF total_count > 0 THEN
      per_row := update_elapsed_time / total_count;
    ELSE
      per_row := 0;
    END IF;

    RAISE NOTICE 'address_current_token_balances updated in % (% per row)', update_elapsed_time, per_row;

    elapsed_time := end_time - start_time;

    RAISE NOTICE 'Ended at %s', end_time;
    RAISE NOTICE 'Elapsed time: %', elapsed_time;
  END $$;
