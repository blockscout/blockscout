defmodule Explorer.Repo.Migrations.AddAuxTypesForDuplicatedLogIndexLogsMigration do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TYPE log_id AS (
      transaction_hash bytea,
      block_hash bytea,
      log_index integer
    );
    """)

    execute("""
    CREATE TYPE nft_id AS (
      block_number bigint,
      log_index integer
    );
    """)
  end

  def down do
    execute("""
    DROP TYPE log_id;
    """)

    execute("""
    DROP TYPE nft_id;
    """)
  end
end
