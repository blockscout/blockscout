defmodule Explorer.Repo.Migrations.RemoveDuplicatesOfCurrentTokenBalances do
  use Ecto.Migration

  def change do
    execute("""
    DELETE FROM address_current_token_balances
    WHERE id in (
        SELECT a.id FROM (SELECT actb.*
        FROM address_current_token_balances actb
        INNER JOIN tokens t
        ON actb.token_contract_address_hash = t.contract_address_hash
        WHERE t.type='ERC-721') AS a
    LEFT JOIN
        (SELECT actb.address_hash, actb.token_contract_address_hash, MAX(actb.value_fetched_at) AS max_value_fetched_at
        FROM address_current_token_balances actb
        INNER JOIN tokens t
        ON actb.token_contract_address_hash = t.contract_address_hash
        WHERE t.type='ERC-721'
        GROUP BY token_contract_address_hash, address_hash) c
    ON a.address_hash=c.address_hash AND a.token_contract_address_hash = c.token_contract_address_hash AND a.value_fetched_at = c.max_value_fetched_at
    WHERE c.address_hash IS NULL
    );
    """)

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
  end
end
