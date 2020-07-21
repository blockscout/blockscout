defmodule Explorer.Repo.Migrations.AddressCoinBalancesPartitioning do
  use Ecto.Migration

  def change do
    rename(table(:address_coin_balances), to: table(:address_coin_balances_old))

    execute("CREATE TABLE address_coin_balances (
      address_hash bytea NOT NULL,
      block_number bigint NOT NULL,
      value numeric(100,0) DEFAULT NULL::numeric,
      value_fetched_at timestamp without time zone,
      inserted_at timestamp without time zone NOT NULL,
      updated_at timestamp without time zone NOT NULL
  ) PARTITION BY RANGE (block_number);")

    execute("CREATE TABLE archive_address_coin_balances PARTITION OF address_coin_balances
  FOR VALUES FROM (0) TO (15841750)
  TABLESPACE archivespace;")

    execute("CREATE TABLE operational_address_coin_balances PARTITION OF address_coin_balances
  FOR VALUES FROM (15841750) TO (600000000)
  TABLESPACE operationalspace;")

    execute(
      "INSERT INTO address_coin_balances (address_hash, block_number, value, value_fetched_at, inserted_at, updated_at) SELECT * FROM address_coin_balances_old;"
    )

    drop(table(:address_coin_balances_old))

    execute(
      "CREATE UNIQUE INDEX unfetched_balances on address_coin_balances(address_hash, block_number) WHERE value_fetched_at IS NULL;"
    )

    create(
      unique_index(:address_coin_balances, [:address_hash, :block_number],
        name: "address_coin_balances_address_hash_block_number_index"
      )
    )

    create(index(:address_coin_balances, [:value_fetched_at], name: "address_coin_balances_value_fetched_at_index"))

    execute(
      "ALTER TABLE address_coin_balances ADD CONSTRAINT address_coin_balances_address_hash_fkey FOREIGN KEY (address_hash) REFERENCES addresses(hash)"
    )
  end
end
