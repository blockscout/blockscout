DO $$
DECLARE
   row_count integer := 1;
   batch_size  integer := 50000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
   iterator  integer := batch_size;
   affected integer;
BEGIN
  DROP TABLE IF EXISTS current_token_balance_temp;
  -- CREATES TEMP TABLE TO STORE TOKEN BALANCES TO BE UPDATED
  CREATE TEMP TABLE current_token_balance_temp(
    address_hash bytea NOT NULL,
    block_number bigint NOT NULL,
    token_contract_address_hash bytea NOT NULL,
    value numeric,
    value_fetched_at timestamp without time zone,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    row_number integer
  );
  INSERT INTO current_token_balance_temp
  SELECT DISTINCT ON (address_hash, token_contract_address_hash)
    address_hash,
    block_number,
    token_contract_address_hash,
    value,
    value_fetched_at,
    inserted_at,
    updated_at,
    ROW_NUMBER () OVER ()
  FROM address_token_balances
  WHERE value IS NOT NULL
  ORDER BY address_hash, token_contract_address_hash, block_number DESC;

  row_count := (SELECT count(*) FROM current_token_balance_temp);
  RAISE NOTICE '% items to be updated', row_count;

  -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
  WHILE row_count > 0 LOOP
    -- INSERT THE TOKEN BALANCES AND RETURNS THE ADDRESS HASH AND TOKEN HASH TO BE DELETED
    WITH updated_address_current_token_balances AS (
      INSERT INTO address_current_token_balances (address_hash, block_number, token_contract_address_hash, value, value_fetched_at, inserted_at, updated_at)
      SELECT
        address_hash,
        block_number,
        token_contract_address_hash,
        value,
        value_fetched_at,
        inserted_at,
        updated_at
      FROM current_token_balance_temp
      WHERE current_token_balance_temp.row_number <= iterator
      RETURNING address_hash, token_contract_address_hash
    )
    DELETE FROM current_token_balance_temp
    WHERE (address_hash, token_contract_address_hash) IN (select address_hash, token_contract_address_hash from updated_address_current_token_balances);

    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE '-> % address current token balances updated!', affected;

    -- COMMITS THE BATCH UPDATES
    CHECKPOINT;

    -- UPDATES THE COUNTER SO IT DOESN'T TURN INTO AN INFINITE LOOP
    row_count := (SELECT count(*) FROM current_token_balance_temp);
    iterator := iterator + batch_size;
    RAISE NOTICE '-> % counter', row_count;
    RAISE NOTICE '-> % next batch', iterator;
  END LOOP;
END $$;
