defmodule Explorer.Repo.Migrations.InternalTransactionsPartitioning do
  use Ecto.Migration

  def change do
    rename(table(:internal_transactions), to: table(:internal_transactions_old))

    execute("CREATE TABLE internal_transactions (
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

    execute("CREATE TABLE archive_internal_transactions PARTITION OF internal_transactions
    FOR VALUES FROM ('2010-07-20') TO ('2020-07-20')
    TABLESPACE archivespace;")

    execute("CREATE TABLE operational_internal_transactions PARTITION OF internal_transactions
    FOR VALUES FROM ('2020-07-20') TO ('2030-07-20')
    TABLESPACE operationalspace;")

    execute(
      "INSERT INTO internal_transactions (call_type, created_contract_code, error, gas, gas_used, index, init, input, output, trace_address, type, value, inserted_at, updated_at, created_contract_address_hash, from_address_hash, to_address_hash, transaction_hash, block_number, transaction_index, block_hash, block_index) SELECT * FROM internal_transactions_old;"
    )

    drop(table(:internal_transactions_old))

    execute("ALTER TABLE internal_transactions
    ADD CONSTRAINT internal_transactions_pkey PRIMARY KEY (block_hash, block_index, inserted_at);")

    create(
      index(:internal_transactions, [:block_number, :transaction_index, :index],
        name: "internal_transactions_block_number_DESC__transaction_index_DESC"
      )
    )

    create(
      index(:internal_transactions, [:created_contract_address_hash],
        name: "internal_transactions_created_contract_address_hash_index"
      )
    )

    create(index(:internal_transactions, [:from_address_hash], name: "internal_transactions_from_address_hash_index"))

    create(
      index(:internal_transactions, [:transaction_hash, :index],
        name: "internal_transactions_transaction_hash_index_index"
      )
    )

    execute(
      "CREATE INDEX internal_transactions_created_contract_address_hash_partial_ind on internal_transactions (created_contract_address_hash, block_number DESC, transaction_index DESC, index DESC) WHERE type::text = 'call'::text AND index > 0 OR type::text <> 'call'::text"
    )

    execute(
      "CREATE INDEX internal_transactions_from_address_hash_partial_index on internal_transactions (from_address_hash, block_number DESC, transaction_index DESC, index DESC) WHERE type::text = 'call'::text AND index > 0 OR type::text <> 'call'::text"
    )

    execute(
      "CREATE INDEX internal_transactions_to_address_hash_partial_index ON internal_transactions (to_address_hash, block_number DESC, transaction_index DESC, index DESC) WHERE type::text = 'call'::text AND index > 0 OR type::text <> 'call'::text"
    )

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_block_hash_fkey FOREIGN KEY (block_hash) REFERENCES blocks(hash)"
    )

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_created_contract_address_hash_fkey FOREIGN KEY (created_contract_address_hash) REFERENCES addresses(hash)"
    )

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_from_address_hash_fkey FOREIGN KEY (from_address_hash) REFERENCES addresses(hash)"
    )

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_to_address_hash_fkey FOREIGN KEY (to_address_hash) REFERENCES addresses(hash)"
    )

    execute(
      "ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_transaction_hash_fkey FOREIGN KEY (transaction_hash) REFERENCES transactions(hash)"
    )
  end
end
