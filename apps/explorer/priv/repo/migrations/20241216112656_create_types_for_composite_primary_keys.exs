defmodule Explorer.Repo.Migrations.CreateTypesForCompositePrimaryKeys do
  use Ecto.Migration

  def up do
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
  end

  def down do
    execute("""
    DROP TYPE token_transfer_id;
    """)

    execute("""
    DROP TYPE nft_current_token_balance_id;
    """)

    execute("""
    DROP TYPE ft_current_token_balance_id;
    """)
  end
end
