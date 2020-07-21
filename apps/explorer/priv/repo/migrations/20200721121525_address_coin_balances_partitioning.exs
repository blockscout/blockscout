defmodule Explorer.Repo.Migrations.AddressCoinBalancesPartitioning do
  use Ecto.Migration

  def change do
    rename(table(:address_coin_balances), to: table(:address_coin_balances_old))

    execute("CREATE TABLE public.address_coin_balances (
      address_hash bytea NOT NULL,
      block_number bigint NOT NULL,
      value numeric(100,0) DEFAULT NULL::numeric,
      value_fetched_at timestamp without time zone,
      inserted_at timestamp without time zone NOT NULL,
      updated_at timestamp without time zone NOT NULL
  ) PARTITION BY RANGE (block_number);")

    execute("DROP INDEX address_coin_balances_address_hash_block_number_index;")
    execute("DROP INDEX unfetched_balances;")
    execute("DROP INDEX address_coin_balances_value_fetched_at_index;")

    execute("CREATE INDEX address_coin_balances_value_fetched_at_index on address_coin_balances(value_fetched_at);")

    execute(
      "CREATE UNIQUE INDEX unfetched_balances on address_coin_balances(address_hash, block_number) WHERE value_fetched_at IS NULL;"
    )

    execute(
      "CREATE UNIQUE INDEX address_coin_balances_address_hash_block_number_index on address_coin_balances(address_hash, block_number);"
    )

    execute("ALTER TABLE address_coin_balances_old DROP CONSTRAINT address_coin_balances_address_hash_fkey;")

    execute(
      "ALTER TABLE address_coin_balances ADD CONSTRAINT address_coin_balances_address_hash_fkey FOREIGN KEY (address_hash) REFERENCES addresses(hash)"
    )

    execute("CREATE TABLE archive_address_coin_balances PARTITION OF address_coin_balances
    FOR VALUES FROM (0) TO (15841750)
    TABLESPACE archivespace;")

    execute("CREATE TABLE operational_address_coin_balances PARTITION OF address_coin_balances
    FOR VALUES FROM (15841750) TO (600000000)
    TABLESPACE operationalspace;")
  end
end
