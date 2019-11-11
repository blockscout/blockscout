defmodule Explorer.Repo.Migrations.UpdateInternalTransactionsFillBlockHashBlockIndex do
  use Ecto.Migration

  def change do
    execute("""
   	DO $$
    DECLARE
      max_block_number INTEGER := 0;
      current_block_number INTEGER := 0;

    BEGIN

      max_block_number := (SELECT max(number) FROM blocks);

      RAISE NOTICE 'max_block_number value: %', max_block_number;

      DROP TABLE IF EXISTS updated_blocks_in_internal_transactions_with_block_hash;

      CREATE TABLE updated_blocks_in_internal_transactions_with_block_hash(
        block_number integer
      );
      
      INSERT INTO updated_blocks_in_internal_transactions_with_block_hash(block_number) VALUES(max_block_number);
      
      current_block_number := (SELECT block_number FROM updated_blocks_in_internal_transactions_with_block_hash);
      
      -- COMMIT TABLE CREATION
        COMMIT;
      
      WHILE current_block_number >= 0 LOOP
        current_block_number := (SELECT block_number FROM updated_blocks_in_internal_transactions_with_block_hash);
        
        UPDATE internal_transactions itx
        SET block_hash = with_block.block_hash, block_index = with_block.block_index
        FROM (
          SELECT i.transaction_hash,
            i.index,
            t.block_hash,
            row_number() OVER(
             PARTITION BY t.block_hash
             ORDER BY i.transaction_hash, i.index
            ) - 1 AS block_index
          FROM internal_transactions AS i
          JOIN transactions AS t
          ON t.hash = i.transaction_hash
          WHERE i.block_number = current_block_number
        ) AS with_block
        WHERE itx.transaction_hash = with_block.transaction_hash
        AND itx.index = with_block.index;
        
        RAISE NOTICE '-> updated % block number', current_block_number;
        
        current_block_number := current_block_number - 1;
        
        UPDATE updated_blocks_in_internal_transactions_with_block_hash SET block_number = current_block_number;
        
        -- COMMIT THE BATCH UPDATES
          COMMIT;
      END LOOP;
      
      RAISE NOTICE 'SCRIPT FINISHED';
      
      DROP TABLE updated_blocks_in_internal_transactions_with_block_hash;
    END $$;
    """)
  end
end
