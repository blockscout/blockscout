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
  insert_start_time   TIMESTAMP WITHOUT TIME ZONE;
  insert_end_time     TIMESTAMP WITHOUT TIME ZONE;
  insert_elapsed_time INTERVAL;
  per_row             INTERVAL;
BEGIN
  RAISE NOTICE 'Started at %', start_time;

  temp_start_time := clock_timestamp();

  DROP TABLE IF EXISTS address_token_balances_without_required_current;
  CREATE TEMP TABLE address_token_balances_without_required_current(
    token_contract_address_hash bytea NOT NULL,
    address_hash bytea NOT NULL,
    row_number integer NOT NULL
  );

  INSERT INTO address_token_balances_without_required_current
  SELECT token_contract_address_hash,
         address_hash,
         ROW_NUMBER() OVER ()
  FROM (
      SELECT DISTINCT token_contract_address_hash,
                      address_hash
      FROM address_token_balances
      WHERE value IS NOT NULL
      EXCEPT
      SELECT token_contract_address_hash,
             address_hash
      FROM address_current_token_balances
    ) AS diff
  ORDER BY address_hash,
           token_contract_address_hash DESC;

  temp_end_time := clock_timestamp();
  temp_elapsed_time := temp_end_time - temp_start_time;
  total_count := (SELECT COUNT(*) FROM address_token_balances_without_required_current);

  RAISE NOTICE 'address_token_balances_without_required_current TEMP table filled in %', temp_elapsed_time;

  remaining_count := total_count;

  RAISE NOTICE '% address_current_token_balances to be inserted', remaining_count;

  insert_start_time := clock_timestamp();

  -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
  WHILE remaining_count > 0 LOOP
    INSERT INTO address_current_token_balances (address_hash,
                                                token_contract_address_hash,
                                                block_number,
                                                value,
                                                value_fetched_at,
                                                inserted_at,
                                                updated_at)
    SELECT address_token_balances_without_required_current.address_hash,
           address_token_balances_without_required_current.token_contract_address_hash,
           address_token_blocks.block_number,
           address_token_balances.value,
           address_token_balances.value_fetched_at,
           address_token_balances.inserted_at,
           address_token_balances.updated_at
    FROM address_token_balances_without_required_current
    INNER JOIN (
        SELECT address_hash,
               token_contract_address_hash,
               MAX(block_number) AS block_number
        FROM address_token_balances
        GROUP BY address_hash,
                 token_contract_address_hash
      ) AS address_token_blocks
    ON address_token_blocks.address_hash = address_token_balances_without_required_current.address_hash AND
       address_token_blocks.token_contract_address_hash = address_token_balances_without_required_current.token_contract_address_hash
    INNER JOIN address_token_balances
    ON address_token_balances.address_hash = address_token_balances_without_required_current.address_hash AND
       address_token_balances.token_contract_address_hash = address_token_balances_without_required_current.token_contract_address_hash AND
       address_token_balances.block_number = address_token_blocks.block_number
    WHERE address_token_balances_without_required_current.row_number <= iterator
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '-> % address current token balances inserted.', updated_count;

    DELETE FROM address_token_balances_without_required_current
    WHERE address_token_balances_without_required_current.row_number <= iterator;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '-> % address token balances without required current removed from queue.', deleted_count;

    -- COMMITS THE BATCH UPDATES
    CHECKPOINT;

    remaining_count := remaining_count - deleted_count;
    iterator := iterator + batch_size;
    RAISE NOTICE '-> % remaining', remaining_count;
    RAISE NOTICE '-> % next batch', iterator;
    insert_elapsed_time := clock_timestamp() - insert_start_time;
    completed_count := total_count - remaining_count;
    per_row := insert_elapsed_time / completed_count;
    RAISE NOTICE '-> Estimated time until completion: %s', per_row * remaining_count;
  END LOOP;

  end_time := clock_timestamp();
  insert_end_time := end_time;
  insert_elapsed_time = insert_end_time - insert_start_time;

  IF total_count > 0 THEN
    per_row := insert_elapsed_time / total_count;
  ELSE
    per_row := 0;
  END IF;

  RAISE NOTICE 'address_current_token_balances updated in % (% per row)', insert_elapsed_time, per_row;

  elapsed_time := end_time - start_time;

  RAISE NOTICE 'Ended at %s', end_time;
  RAISE NOTICE 'Elapsed time: %', elapsed_time;
END $$;
