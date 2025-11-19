defmodule Explorer.Repo.Migrations.DropTokensContractAddressHashIndex do
  use Ecto.Migration

  def change do
    execute("""
    DO $$
    BEGIN
    -- 1. Check if the index exists
    IF EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relname = 'tokens_contract_address_hash_index'
        AND n.nspname = 'public'
    ) THEN
      RAISE NOTICE 'Index tokens_contract_address_hash_index exists. Proceeding...';

      -- 2. Drop the FK constraint (only if it exists)
      IF EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conname = 'token_instances_token_contract_address_hash_fkey'
            AND conrelid = 'public.token_instances'::regclass
      ) THEN
          RAISE NOTICE 'Dropping foreign key token_instances_token_contract_address_hash_fkey...';
          EXECUTE '
              ALTER TABLE public.token_instances
              DROP CONSTRAINT token_instances_token_contract_address_hash_fkey
          ';
      END IF;

      -- 3. Drop the redundant index
      RAISE NOTICE 'Dropping index tokens_contract_address_hash_index...';
      EXECUTE 'DROP INDEX public.tokens_contract_address_hash_index';

      -- 4. Recreate the FK constraint
      RAISE NOTICE 'Recreating foreign key token_instances_token_contract_address_hash_fkey...';
      EXECUTE '
          ALTER TABLE public.token_instances
          ADD CONSTRAINT token_instances_token_contract_address_hash_fkey
          FOREIGN KEY (token_contract_address_hash)
          REFERENCES public.tokens(contract_address_hash)
      ';
    ELSE
      RAISE NOTICE 'Index tokens_contract_address_hash_index does NOT exist. Nothing to do.';
    END IF;
    END $$;
    """)
  end
end
