DO $$
 DECLARE
    row_count integer := 1;
    batch_size  integer := 50000; -- HOW MANY ITEMS WILL BE UPDATED AT TIME
    iterator  integer := batch_size;
    affected integer;
 BEGIN
   DROP TABLE IF EXISTS addresses_nonce_temp;

   -- CREATES TEMP TABLE TO STORE THE ADDRESS NONCE TO BE UPDATED
   CREATE TEMP TABLE addresses_nonce_temp(
     from_address_hash bytea,
     nonce integer,
     row_number integer
   );

   INSERT INTO addresses_nonce_temp
   SELECT DISTINCT ON (from_address_hash)
     from_address_hash,
     nonce,
     ROW_NUMBER () OVER ()
   FROM transactions
   ORDER BY from_address_hash, nonce DESC;

   row_count := (SELECT count(*) FROM addresses_nonce_temp);

   RAISE NOTICE '% items to be updated', row_count;

   -- ITERATES THROUGH THE ITEMS UNTIL THE TEMP TABLE IS EMPTY
   WHILE row_count > 0 LOOP
     -- UPDATES THE ADDRESS NONCE AND RETURNS THE ADDRESS_HASH
     WITH updated_addresses AS (
       UPDATE addresses SET nonce = addresses_nonce_temp.nonce
       FROM addresses_nonce_temp
       WHERE addresses_nonce_temp.from_address_hash = addresses.hash
       AND addresses_nonce_temp.row_number <= iterator
       RETURNING addresses_nonce_temp.from_address_hash
     )
     DELETE FROM addresses_nonce_temp
     WHERE (from_address_hash) IN (select from_address_hash from updated_addresses);

     GET DIAGNOSTICS affected = ROW_COUNT;
     RAISE NOTICE '-> % addresses updated!', affected;

     -- COMMITS THE BATCH UPDATES
     CHECKPOINT;

     -- UPDATES THE COUNTER SO IT DOESN'T TURN INTO A INFINITE LOOP
     row_count := (SELECT count(*) FROM addresses_nonce_temp);
     iterator := iterator + batch_size;

     RAISE NOTICE '-> % counter', row_count;
     RAISE NOTICE '-> % next batch', iterator;
   END LOOP;
 END $$;
