DO $$
  DECLARE
    row_count  integer := 1;
    batch_size integer := 50000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
    iterator   integer := batch_size;
    affected   integer;
  BEGIN
    DROP TABLE IF EXISTS address_token_temp;
    CREATE TEMP TABLE address_token_temp
    (
      address_hash                bytea NOT NULL,
      token_contract_address_hash bytea NOT NULL,
      row_number                  integer
    );
    INSERT INTO address_token_temp
    SELECT DISTINCT ON (address_hash, token_contract_address_hash) address_hash,
                                                                   token_contract_address_hash,
                                                                   ROW_NUMBER() OVER ()
    FROM address_token_balances
    WHERE value IS NOT NULL
    ORDER BY address_hash, token_contract_address_hash;

    row_count := (SELECT COUNT(*) FROM address_token_temp);
    RAISE NOTICE '% items to be updated', row_count;

    -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
    WHILE row_count > 0
      LOOP
        UPDATE address_current_token_balances
        SET block_number = new_address_current_token_balances.block_number,
            value        = new_address_current_token_balances.value,
            inserted_at  = new_address_current_token_balances.inserted_at,
            updated_at   = new_address_current_token_balances.updated_at
        FROM (
               SELECT address_token_blocks.address_hash,
                      address_token_blocks.token_contract_address_hash,
                      address_token_blocks.block_number,
                      address_token_balances.value,
                      MIN(address_token_balances.inserted_at) OVER w AS inserted_at,
                      MAX(address_token_balances.updated_at) OVER w  AS updated_at
               FROM (
                      SELECT address_token_batch.address_hash,
                             address_token_batch.token_contract_address_hash,
                             MAX(address_token_balances.block_number) AS block_number
                      FROM (
                             SELECT address_hash,
                                    token_contract_address_hash
                             FROM address_token_temp
                             WHERE address_token_temp.row_number <= iterator
                           ) AS address_token_batch
                             INNER JOIN address_token_balances
                                        ON address_token_balances.address_hash = address_token_batch.address_hash AND
                                           address_token_balances.token_contract_address_hash =
                                           address_token_batch.token_contract_address_hash
                      GROUP BY address_token_batch.address_hash,
                               address_token_batch.token_contract_address_hash
                    ) AS address_token_blocks
                      INNER JOIN address_token_balances
                                 ON address_token_balances.address_hash = address_token_blocks.address_hash AND
                                    address_token_balances.token_contract_address_hash =
                                    address_token_blocks.token_contract_address_hash AND
                                    address_token_balances.block_number = address_token_blocks.block_number
                    WINDOW w AS (PARTITION BY address_token_balances.address_hash, address_token_balances.token_contract_address_hash)
             ) AS new_address_current_token_balances
        WHERE new_address_current_token_balances.address_hash = address_current_token_balances.address_hash
          AND
            new_address_current_token_balances.token_contract_address_hash =
            address_current_token_balances.token_contract_address_hash
          AND
          (new_address_current_token_balances.block_number != address_current_token_balances.block_number OR
           new_address_current_token_balances.value != address_current_token_balances.value);

        GET DIAGNOSTICS affected = ROW_COUNT;
        RAISE NOTICE '-> % address current token balances updated.', affected;

        DELETE
        FROM address_token_temp
        WHERE address_token_temp.row_number <= iterator;

        GET DIAGNOSTICS affected = ROW_COUNT;
        RAISE NOTICE '-> % address tokens removed from queue.', affected;

        -- COMMITS THE BATCH UPDATES
        CHECKPOINT;

        -- UPDATES THE COUNTER SO IT DOESN'T TURN INTO AN INFINITE LOOP
        row_count := (SELECT COUNT(*) FROM address_token_temp);
        iterator := iterator + batch_size;
        RAISE NOTICE '-> % counter', row_count;
        RAISE NOTICE '-> % next batch', iterator;
      END LOOP;
  END $$;
