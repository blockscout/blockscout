defmodule Explorer.Repo.Migrations.BlockRewardsPartitioning do
  use Ecto.Migration

  def change do
    # rename(table(:block_rewards), to: table(:block_rewards_old))

    # execute("CREATE TABLE public.block_rewards (
    #     address_hash bytea NOT NULL,
    #     address_type character varying(255) NOT NULL,
    #     block_hash bytea NOT NULL,
    #     reward numeric(100,0),
    #     inserted_at timestamp(0) without time zone NOT NULL,
    #     updated_at timestamp(0) without time zone NOT NULL
    # ) PARTITION BY RANGE (inserted_at);")

    # execute("DROP INDEX block_rewards_address_hash_block_hash_address_type_index;")
    # execute("DROP INDEX block_rewards_block_hash_index;")
    # execute("DROP INDEX block_rewards_block_hash_partial_index;")

    # execute(
    #   "CREATE UNIQUE INDEX block_rewards_address_hash_block_hash_address_type_index on block_rewards(address_hash, block_hash, address_type, inserted_at);"
    # )

    # execute("CREATE INDEX block_rewards_block_hash_index on block_rewards(block_hash);")

    # execute(
    #   "CREATE INDEX block_rewards_block_hash_partial_index on block_rewards(block_hash) WHERE address_type::text = 'validator'::text;"
    # )

    # execute("ALTER TABLE block_rewards_old DROP CONSTRAINT block_rewards_address_hash_fkey;")

    # execute(
    #   "ALTER TABLE block_rewards ADD CONSTRAINT block_rewards_address_hash_fkey FOREIGN KEY (address_hash) REFERENCES addresses(hash) ON DELETE CASCADE"
    # )

    # execute("ALTER TABLE block_rewards_old DROP CONSTRAINT block_rewards_block_hash_fkey;")

    # execute(
    #   "ALTER TABLE block_rewards ADD CONSTRAINT block_rewards_block_hash_fkey FOREIGN KEY (block_hash) REFERENCES blocks(hash) ON DELETE CASCADE"
    # )

    # execute("CREATE TABLE archive_block_rewards PARTITION OF block_rewards
    # FOR VALUES FROM ('2010-07-20') TO ('2020-07-20')
    # TABLESPACE archivespace;")

    # execute("CREATE TABLE operational_block_rewards PARTITION OF block_rewards
    # FOR VALUES FROM ('2020-07-20') TO ('2030-07-20')
    # TABLESPACE operationalspace;")
  end
end
