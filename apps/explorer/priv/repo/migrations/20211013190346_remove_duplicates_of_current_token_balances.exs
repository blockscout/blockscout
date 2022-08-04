defmodule Explorer.Repo.Migrations.RemoveDuplicatesOfCurrentTokenBalances do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE address_current_token_balances
    SET token_id = NULL
    WHERE id in (
        SELECT a.id FROM (SELECT actb.*
        FROM address_current_token_balances actb
        INNER JOIN tokens t
        ON actb.token_contract_address_hash = t.contract_address_hash
        WHERE t.type='ERC-721'
        AND actb.token_id IS NOT NULL
        ) a
    );
    """)

    execute("""
    UPDATE address_current_token_balances
    SET token_type = t.type
    FROM tokens t
    WHERE address_current_token_balances.token_type IS NULL
    AND t.contract_address_hash = address_current_token_balances.token_contract_address_hash;
    """)

    execute("""
    UPDATE address_token_balances
    SET token_type = t.type
    FROM tokens t
    WHERE address_token_balances.token_type IS NULL
    AND t.contract_address_hash = address_token_balances.token_contract_address_hash;
    """)
  end
end
