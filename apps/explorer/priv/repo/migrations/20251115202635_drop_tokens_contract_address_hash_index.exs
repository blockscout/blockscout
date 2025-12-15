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

      -- 2. Drop the token_instances_token_contract_address_hash_fkey FK constraint (only if it exists)
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

      -- 3. Drop the bridged_tokens_home_token_contract_address_hash_fkey FK constraint (only if it exists)
      IF EXISTS (
          SELECT 1 FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relname = 'bridged_tokens' AND n.nspname = 'public'
      ) THEN
        IF EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conname = 'bridged_tokens_home_token_contract_address_hash_fkey'
              AND conrelid = 'public.bridged_tokens'::regclass
        ) THEN
            RAISE NOTICE 'Dropping foreign key bridged_tokens_home_token_contract_address_hash_fkey...';
            EXECUTE '
                ALTER TABLE public.bridged_tokens
                DROP CONSTRAINT bridged_tokens_home_token_contract_address_hash_fkey
            ';
        END IF;
      END IF;

      -- 4. Drop the redundant index
      RAISE NOTICE 'Dropping index tokens_contract_address_hash_index...';
      EXECUTE 'DROP INDEX public.tokens_contract_address_hash_index';

      -- 5. Recreate the token_instances_token_contract_address_hash_fkey FK constraint
      RAISE NOTICE 'Recreating foreign key token_instances_token_contract_address_hash_fkey...';
      EXECUTE '
          ALTER TABLE public.token_instances
          ADD CONSTRAINT token_instances_token_contract_address_hash_fkey
          FOREIGN KEY (token_contract_address_hash)
          REFERENCES public.tokens(contract_address_hash)
      ';

      -- 6. Recreate the bridged_tokens_home_token_contract_address_hash_fkey FK constraint (only if table exists)
      IF EXISTS (
          SELECT 1 FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relname = 'bridged_tokens' AND n.nspname = 'public'
      ) THEN
        RAISE NOTICE 'Recreating foreign key bridged_tokens_home_token_contract_address_hash_fkey...';
        EXECUTE '
            ALTER TABLE public.bridged_tokens
            ADD CONSTRAINT bridged_tokens_home_token_contract_address_hash_fkey
            FOREIGN KEY (home_token_contract_address_hash)
            REFERENCES public.tokens(contract_address_hash)
        ';
      END IF;
    ELSE
      RAISE NOTICE 'Index tokens_contract_address_hash_index does NOT exist. Nothing to do.';
    END IF;
    END $$;
    """)
  end
end
