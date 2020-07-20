defmodule Explorer.Repo.Migrations.TransactionnsPartitioning do
  use Ecto.Migration

  def change do

    rename table(:transactions), to: table(:transactions_old)

    drop(index(:transactions, :inserted_at))
    drop(index(:transactions, :updated_at))

    drop(index(:transactions, :status))

    drop(
      index(
        :transactions,
        ["block_number DESC NULLS FIRST", "index DESC NULLS FIRST"],
        name: "transactions_recent_collated_index"
      )
    )

    drop(
      index(
        :transactions,
        [:from_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_from_address_hash_recent_collated_index"
      )
    )

    drop(
      index(
        :transactions,
        [:to_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_to_address_hash_recent_collated_index"
      )
    )

    drop(
      index(
        :transactions,
        [:created_contract_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_created_contract_address_hash_recent_collated_index"
      )
    )

    execute("DROP INDEX pending_txs_index;")

    create(index(:transactions_old, :inserted_at))
    create(index(:transactions_old, :updated_at))

    create(index(:transactions_old, :status))

    create(
      index(
        :transactions_old,
        ["block_number DESC NULLS FIRST", "index DESC NULLS FIRST"],
        name: "transactions_old_recent_collated_index"
      )
    )

    create(
      index(
        :transactions_old,
        [:from_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_old_from_address_hash_recent_collated_index"
      )
    )

    create(
      index(
        :transactions_old,
        [:to_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_old_to_address_hash_recent_collated_index"
      )
    )

    create(
      index(
        :transactions_old,
        [:created_contract_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_old_created_contract_address_hash_recent_collated_index"
      )
    )

    execute("CREATE INDEX pending_txs_old_index ON public.transactions_old USING btree (inserted_at, hash) WHERE ((block_hash IS NULL) AND ((error IS NULL) OR ((error)::text <> 'dropped/replaced'::text)));")

    execute("CREATE TABLE transactions (
      cumulative_gas_used numeric(100,0),
      error character varying(255),
      gas numeric(100,0) NOT NULL,
      gas_price numeric(100,0) NOT NULL,
      gas_used numeric(100,0),
      hash bytea NOT NULL,
      index integer,
      input bytea NOT NULL,
      nonce integer NOT NULL,
      r numeric(100,0) NOT NULL,
      s numeric(100,0) NOT NULL,
      status integer,
      v numeric(100,0) NOT NULL,
      value numeric(100,0) NOT NULL,
      inserted_at timestamp without time zone NOT NULL,
      updated_at timestamp without time zone NOT NULL,
      block_hash bytea,
      block_number integer,
      from_address_hash bytea NOT NULL,
      to_address_hash bytea,
      created_contract_address_hash bytea,
      created_contract_code_indexed_at timestamp without time zone,
      earliest_processing_start timestamp without time zone,
      old_block_hash bytea,
      revert_reason text,
      CONSTRAINT collated_block_number CHECK (((block_hash IS NULL) OR (block_number IS NOT NULL))),
      CONSTRAINT collated_cumalative_gas_used CHECK (((block_hash IS NULL) OR (cumulative_gas_used IS NOT NULL))),
      CONSTRAINT collated_gas_used CHECK (((block_hash IS NULL) OR (gas_used IS NOT NULL))),
      CONSTRAINT collated_index CHECK (((block_hash IS NULL) OR (index IS NOT NULL))),
      CONSTRAINT error CHECK (((status = 0) OR ((status <> 0) AND (error IS NULL)))),
      CONSTRAINT pending_block_number CHECK (((block_hash IS NOT NULL) OR (block_number IS NULL))),
      CONSTRAINT pending_cumalative_gas_used CHECK (((block_hash IS NOT NULL) OR (cumulative_gas_used IS NULL))),
      CONSTRAINT pending_gas_used CHECK (((block_hash IS NOT NULL) OR (gas_used IS NULL))),
      CONSTRAINT pending_index CHECK (((block_hash IS NOT NULL) OR (index IS NULL))),
      CONSTRAINT status CHECK ((((block_hash IS NULL) AND (status IS NULL)) OR (block_hash IS NOT NULL) OR ((status = 0) AND ((error)::text = 'dropped/replaced'::text))))
  ) PARTITION BY RANGE (inserted_at);")

  execute("ALTER TABLE transactions
  ADD CONSTRAINT transactions_new_pkey PRIMARY KEY (hash, inserted_at);")

  execute("ALTER TABLE transactions ADD UNIQUE (block_hash, index, inserted_at);")

  execute("CREATE TABLE archive_transactions PARTITION OF transactions
  FOR VALUES FROM ('2008-01-01') TO ('2020-07-15 09:06:12')
  TABLESPACE archivespace;")

  execute("CREATE TABLE operational_transactions PARTITION OF transactions
  FOR VALUES FROM ('2020-07-15 09:06:12') TO ('2100-07-15')
  TABLESPACE operationalspace;")

  execute("ALTER TABLE internal_transactions DROP CONSTRAINT internal_transactions_transaction_hash_fkey;")
  execute("ALTER TABLE internal_transactions ADD COLUMN transaction_inserted_at TIMESTAMP WITHOUT TIME ZONE;")
  execute("ALTER TABLE internal_transactions ADD CONSTRAINT internal_transactions_transaction_hash_fkey FOREIGN KEY (transaction_hash, transaction_inserted_at) REFERENCES transactions(hash, inserted_at) ON DELETE CASCADE")

  execute("ALTER TABLE logs DROP CONSTRAINT logs_transaction_hash_fkey;")
  execute("ALTER TABLE logs ADD COLUMN transaction_inserted_at TIMESTAMP WITHOUT TIME ZONE;")
  execute("ALTER TABLE logs ADD CONSTRAINT logs_transaction_hash_fkey FOREIGN KEY (transaction_hash, transaction_inserted_at) REFERENCES transactions(hash, inserted_at) ON DELETE CASCADE")

  execute("ALTER TABLE token_transfers DROP CONSTRAINT token_transfers_transaction_hash_fkey;")
  execute("ALTER TABLE token_transfers ADD COLUMN transaction_inserted_at TIMESTAMP WITHOUT TIME ZONE;")
  execute("ALTER TABLE token_transfers ADD CONSTRAINT token_transfers_transaction_hash_fkey FOREIGN KEY (transaction_hash, transaction_inserted_at) REFERENCES transactions(hash, inserted_at) ON DELETE CASCADE")

  execute("ALTER TABLE transaction_forks DROP CONSTRAINT transaction_forks_hash_fkey;")
  execute("ALTER TABLE transaction_forks ADD COLUMN transaction_inserted_at TIMESTAMP WITHOUT TIME ZONE;")
  execute("ALTER TABLE transaction_forks ADD CONSTRAINT token_transfers_hash_fkey FOREIGN KEY (hash, transaction_inserted_at) REFERENCES transactions(hash, inserted_at) ON DELETE CASCADE")


  execute("ALTER TABLE transactions_old DROP CONSTRAINT transactions_block_hash_fkey;")
  execute("ALTER TABLE transactions ADD CONSTRAINT transactions_block_hash_fkey FOREIGN KEY (block_hash) REFERENCES blocks(hash) ON DELETE CASCADE")

  execute("ALTER TABLE transactions_old DROP CONSTRAINT transactions_created_contract_address_hash_fkey;")
  execute("ALTER TABLE transactions ADD CONSTRAINT transactions_created_contract_address_hash_fkey FOREIGN KEY (created_contract_address_hash) REFERENCES addresses(hash) ON DELETE CASCADE")

  execute("ALTER TABLE transactions_old DROP CONSTRAINT transactions_from_address_hash_fkey;")
  execute("ALTER TABLE transactions ADD CONSTRAINT transactions_from_address_hash_fkey FOREIGN KEY (from_address_hash) REFERENCES addresses(hash) ON DELETE CASCADE")

  execute("ALTER TABLE transactions_old DROP CONSTRAINT transactions_to_address_hash_fkey;")
  execute("ALTER TABLE transactions ADD CONSTRAINT transactions_to_address_hash_fkey FOREIGN KEY (to_address_hash) REFERENCES addresses(hash) ON DELETE CASCADE")

  create(index(:archive_transactions, :inserted_at))
    create(index(:archive_transactions, :updated_at))

    create(index(:archive_transactions, :status))

    create(
      index(
        :archive_transactions,
        ["block_number DESC NULLS FIRST", "index DESC NULLS FIRST"],
        name: "transactions_recent_collated_index"
      )
    )

    create(
      index(
        :archive_transactions,
        [:from_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_from_address_hash_recent_collated_index"
      )
    )

    create(
      index(
        :archive_transactions,
        [:to_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_to_address_hash_recent_collated_index"
      )
    )

    create(
      index(
        :archive_transactions,
        [:created_contract_address_hash, "block_number DESC NULLS FIRST", "index DESC NULLS FIRST", :hash],
        name: "transactions_created_contract_address_hash_recent_collated_index"
      )
    )

    execute("CREATE INDEX pending_txs_index ON public.archive_transactions USING btree (inserted_at, hash) WHERE ((block_hash IS NULL) AND ((error IS NULL) OR ((error)::text <> 'dropped/replaced'::text)));")

  end
end
