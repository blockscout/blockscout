defmodule Explorer.Repo.Migrations.BlocksPartitioning do
  use Ecto.Migration

  def change do
    #     rename table(:blocks), to: table(:blocks_old)

    #     drop(index(:blocks, [:timestamp]))
    #     drop(index(:blocks, [:parent_hash], unique: true, where: ~s(consensus), name: :one_consensus_child_per_parent))
    #     drop(index(:blocks, [:number], unique: true, where: ~s(consensus), name: :one_consensus_block_at_height))
    #     drop(index(:blocks, :inserted_at))
    #     drop(index(:blocks, [:miner_hash]))
    #     drop(index(:blocks, [:miner_hash, :number]))
    #     drop(index(:blocks, [:number]))
    #     drop(index(:blocks, [:consensus]))

    #     create(index(:blocks_old, [:timestamp]))
    #     create(index(:blocks_old, [:parent_hash], unique: true, where: ~s(consensus), name: :one_consensus_child_per_parent_old))
    #     create(index(:blocks_old, [:number], unique: true, where: ~s(consensus), name: :one_consensus_block_at_height_old))
    #     create(index(:blocks_old, :inserted_at))
    #     create(index(:blocks_old, [:miner_hash]))
    #     create(index(:blocks_old, [:miner_hash, :number]))
    #     create(index(:blocks_old, [:number]))
    #     create(index(:blocks_old, [:consensus]))

    #     execute("
    #         CREATE TABLE public.blocks (
    #         consensus boolean NOT NULL,
    #         difficulty numeric(50,0),
    #         gas_limit numeric(100,0) NOT NULL,
    #         gas_used numeric(100,0) NOT NULL,
    #         hash bytea NOT NULL,
    #         miner_hash bytea NOT NULL,
    #         nonce bytea NOT NULL,
    #         number bigint NOT NULL,
    #         parent_hash bytea NOT NULL,
    #         size integer,
    #         \"timestamp\" timestamp without time zone NOT NULL,
    #         total_difficulty numeric(50,0),
    #         inserted_at timestamp without time zone NOT NULL,
    #         updated_at timestamp without time zone NOT NULL,
    #         refetch_needed boolean DEFAULT false
    #     ) PARTITION BY RANGE (timestamp);")

    #     # execute("CREATE TABLESPACE archivespace LOCATION '/Users/viktor/Documents/POANetwork/db_paritioning/archive';")
    #     # execute("CREATE TABLESPACE operationalspace LOCATION '/Users/viktor/Documents/POANetwork/db_paritioning/operational';")

    #     execute("CREATE TABLE archive_blocks PARTITION OF blocks
    #     FOR VALUES FROM ('2008-01-01') TO ('2020-07-15')
    #     TABLESPACE archivespace;")

    #     execute("ALTER TABLE archive_blocks
    #     ADD CONSTRAINT archive_blocks_pkey PRIMARY KEY (hash, timestamp);")

    #     execute("ALTER TABLE blocks
    #     ADD CONSTRAINT partitioned_blocks_pkey PRIMARY KEY (hash, timestamp);")

    #     execute("ALTER TABLE ONLY archive_blocks
    #     ADD CONSTRAINT archive_blocks_miner_hash_fkey FOREIGN KEY (miner_hash) REFERENCES addresses(hash);
    #     ")

    #     create(index(:archive_blocks, [:timestamp]))
    #     create(index(:archive_blocks, [:parent_hash], unique: true, where: ~s(consensus), name: :one_consensus_child_per_parent))
    #     create(index(:archive_blocks, [:number], unique: true, where: ~s(consensus), name: :one_consensus_block_at_height))
    #     create(index(:archive_blocks, :inserted_at))
    #     create(index(:archive_blocks, [:miner_hash]))
    #     create(index(:archive_blocks, [:miner_hash, :number]))
    #     create(index(:archive_blocks, [:number]))
    #     create(index(:archive_blocks, [:consensus]))
  end
end
