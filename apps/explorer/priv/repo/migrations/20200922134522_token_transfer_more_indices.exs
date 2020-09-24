defmodule Explorer.Repo.Migrations.TokenTransferMoreIndices do
  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM token_transfers WHERE log_index <= -1000000;
    """)

    create(index(:token_transfers, ["block_number DESC, amount DESC, log_index DESC"]))

    create(
      index(:token_transfers, ["block_number DESC, transaction_hash DESC, from_address_hash DESC, to_address_hash DESC"])
    )

    execute("""
    INSERT INTO token_transfers (
      SELECT hash, block_hash, -(index*1000+1000000) AS log_index, from_address_hash, to_address_hash, value, null,
          tokens.contract_address_hash, tx.inserted_at, tx.updated_at, block_number, null
      FROM transactions AS tx, tokens
      WHERE value > 0 AND tokens.symbol = 'cGLD' AND to_address_hash IS NOT NULL
    );
    """)

    execute("""
    INSERT INTO token_transfers (
      SELECT transaction_hash, block_hash, -(index+transaction_index*1000+1000000) AS log_index, from_address_hash, to_address_hash, value, null,
        tokens.contract_address_hash, tx.inserted_at, tx.updated_at, block_number, null
      FROM internal_transactions AS tx, tokens
      WHERE value > 0 AND tokens.symbol = 'cGLD' AND call_type <> 'delegatecall' AND index > 0 AND to_address_hash IS NOT NULL
    );
    """)

    execute("""
    INSERT INTO token_transfers (
      SELECT hash, block_hash, -(index*1000+1000000) AS log_index, from_address_hash, created_contract_address_hash, value, null,
          tokens.contract_address_hash, tx.inserted_at, tx.updated_at, block_number, null
      FROM transactions AS tx, tokens
      WHERE value > 0 AND tokens.symbol = 'cGLD' AND to_address_hash IS NULL AND created_contract_address_hash IS NOT NULL
    );
    """)

    execute("""
    INSERT INTO token_transfers (
      SELECT transaction_hash, block_hash, -(index+transaction_index*1000+1000000) AS log_index, from_address_hash, created_contract_address_hash, value, null,
        tokens.contract_address_hash, tx.inserted_at, tx.updated_at, block_number, null
      FROM internal_transactions AS tx, tokens
      WHERE value > 0 AND tokens.symbol = 'cGLD' AND call_type <> 'delegatecall' AND index > 0 AND to_address_hash IS NULL AND created_contract_address_hash IS NOT NULL
    );
    """)
  end

  def down do
    execute("""
    DELETE FROM token_transfers WHERE log_index <= -1000000;
    """)

    drop(index(:token_transfers, ["block_number DESC, amount DESC, log_index DESC"]))

    drop(
      index(:token_transfers, ["block_number DESC, transaction_hash DESC, from_address_hash DESC, to_address_hash DESC"])
    )
  end
end
