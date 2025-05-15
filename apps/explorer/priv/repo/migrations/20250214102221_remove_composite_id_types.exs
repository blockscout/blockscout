defmodule Explorer.Repo.Migrations.RemoveCompositeIdTypes do
  use Ecto.Migration

  def up do
    execute("""
    DROP TYPE log_id;
    """)

    execute("""
    DROP TYPE nft_id;
    """)

    execute("""
    DROP TYPE token_transfer_id;
    """)

    execute("""
    DROP TYPE nft_current_token_balance_id;
    """)

    execute("""
    DROP TYPE ft_current_token_balance_id;
    """)

    execute("""
    DROP TYPE token_instance_id;
    """)
  end

  def down do
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

    execute("""
    CREATE TYPE token_transfer_id AS (
      transaction_hash bytea,
      block_hash bytea,
      log_index integer
    );
    """)

    execute("""
    CREATE TYPE nft_current_token_balance_id AS (
      address_hash bytea,
      token_contract_address_hash bytea,
      token_id numeric(78,0)
    );
    """)

    execute("""
    CREATE TYPE ft_current_token_balance_id AS (
      address_hash bytea,
      token_contract_address_hash bytea
    );
    """)

    execute("""
    CREATE TYPE token_instance_id AS (
      token_id numeric(78),
      token_contract_address_hash bytea
    );
    """)
  end
end
