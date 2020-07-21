defmodule Explorer.Repo.Migrations.InternalTransactionsPartitioning do
  use Ecto.Migration

  def change do
    rename(table(:internal_transactions), to: table(:internal_transactions_old))

    execute("CREATE TABLE public.internal_transactions (
      call_type character varying(255),
      created_contract_code bytea,
      error character varying(255),
      gas numeric(100,0),
      gas_used numeric(100,0),
      index integer NOT NULL,
      init bytea,
      input bytea,
      output bytea,
      trace_address integer[] NOT NULL,
      type character varying(255) NOT NULL,
      value numeric(100,0) NOT NULL,
      inserted_at timestamp without time zone NOT NULL,
      updated_at timestamp without time zone NOT NULL,
      created_contract_address_hash bytea,
      from_address_hash bytea,
      to_address_hash bytea,
      transaction_hash bytea NOT NULL,
      block_number integer,
      transaction_index integer,
      block_hash bytea NOT NULL,
      block_index integer NOT NULL,
      CONSTRAINT call_has_error_or_result CHECK ((((type)::text <> 'call'::text) OR ((gas IS NOT NULL) AND (((error IS NULL) AND (gas_used IS NOT NULL) AND (output IS NOT NULL)) OR ((error IS NOT NULL) AND (gas_used IS NULL) AND (output IS NULL)))))),
      CONSTRAINT create_has_error_or_result CHECK ((((type)::text <> 'create'::text) OR ((gas IS NOT NULL) AND (((error IS NULL) AND (created_contract_address_hash IS NOT NULL) AND (created_contract_code IS NOT NULL) AND (gas_used IS NOT NULL)) OR ((error IS NOT NULL) AND (created_contract_address_hash IS NULL) AND (created_contract_code IS NULL) AND (gas_used IS NULL)))))),
      CONSTRAINT selfdestruct_has_from_and_to_address_hashes CHECK ((((type)::text <> 'selfdestruct'::text) OR ((from_address_hash IS NOT NULL) AND (gas IS NULL) AND (to_address_hash IS NOT NULL))))
  ) PARTITION BY RANGE (inserted_at)")

    execute("ALTER TABLE internal_transactions_old
    DROP CONSTRAINT internal_transactions_pkey;")

    # execute("DROP INDEX internal_transactions_block_number_DESC__transaction_index_DESC;")
    execute("DROP INDEX internal_transactions_created_contract_address_hash_index;")
    execute("DROP INDEX internal_transactions_created_contract_address_hash_partial_ind;")
    execute("DROP INDEX internal_transactions_from_address_hash_index;")
    execute("DROP INDEX internal_transactions_from_address_hash_partial_index;")
    execute("DROP INDEX internal_transactions_to_address_hash_partial_index;")
    execute("DROP INDEX internal_transactions_transaction_hash_index_index;")

    execute("ALTER TABLE internal_transactions
    ADD CONSTRAINT internal_transactions_pkey PRIMARY KEY (block_hash, block_index, inserted_at);")

    execute("ALTER TABLE internal_transactions_old DROP CONSTRAINT internal_transactions_block_hash_fkey;")

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_block_hash_fkey FOREIGN KEY (block_hash) REFERENCES blocks(hash)"
    )

    execute(
      "ALTER TABLE internal_transactions_old DROP CONSTRAINT internal_transactions_created_contract_address_hash_fkey;"
    )

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_created_contract_address_hash_fkey FOREIGN KEY (created_contract_address_hash) REFERENCES addresses(hash)"
    )

    execute("ALTER TABLE internal_transactions_old DROP CONSTRAINT internal_transactions_from_address_hash_fkey;")

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_from_address_hash_fkey FOREIGN KEY (from_address_hash) REFERENCES addresses(hash)"
    )

    execute("ALTER TABLE internal_transactions_old DROP CONSTRAINT internal_transactions_to_address_hash_fkey;")

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_to_address_hash_fkey FOREIGN KEY (to_address_hash) REFERENCES addresses(hash)"
    )

    execute("ALTER TABLE internal_transactions_old DROP CONSTRAINT internal_transactions_transaction_hash_fkey;")

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_transaction_hash_fkey FOREIGN KEY (transaction_hash) REFERENCES transactions(hash)"
    )

    execute("CREATE TABLE archive_internal_transactions PARTITION OF internal_transactions
    FOR VALUES FROM ('2010-07-20') TO ('2020-07-20')
    TABLESPACE archivespace;")

    execute("CREATE TABLE operational_internal_transactions PARTITION OF internal_transactions
    FOR VALUES FROM ('2020-07-20') TO ('2030-07-20')
    TABLESPACE operationalspace;")
  end
end
