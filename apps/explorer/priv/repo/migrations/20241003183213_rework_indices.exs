defmodule Explorer.Repo.Migrations.ReworkIndices do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:logs, ["block_number ASC, index ASC"]))
    drop_if_exists(index(:logs, [:address_hash]))
    drop_if_exists(index(:logs, [:address_hash, :transaction_hash]))
    drop_if_exists(index(:logs, [:index]))
    # drop_if_exists(index(:logs, [:transaction_hash, :index]))
    if Application.get_env(:explorer, :chain_type) != :celo do
      execute(
        """
        ALTER TABLE logs
        DROP CONSTRAINT logs_pkey,
        ADD PRIMARY KEY (block_hash, index);
        """,
        """
        ALTER TABLE logs
        DROP CONSTRAINT logs_pkey,
        ADD PRIMARY KEY (transaction_hash, block_hash, index);
        """
      )
    end

    create_if_not_exists(index(:logs, [:address_hash, :block_number, :index]))
    create_if_not_exists(index(:logs, [:address_hash, :first_topic, :block_number, :index]))

    drop_if_exists(index(:token_transfers, ["block_number ASC", "log_index ASC"]))
    drop_if_exists(index(:token_transfers, [:block_number]))
    drop_if_exists(index(:token_transfers, [:from_address_hash, :transaction_hash]))
    drop_if_exists(index(:token_transfers, [:to_address_hash, :transaction_hash]))
    drop_if_exists(index(:token_transfers, [:token_contract_address_hash, :transaction_hash]))
    # drop_if_exists(index(:token_transfers, [:transaction_hash, :log_index]))
    if Application.get_env(:explorer, :chain_type) != :celo do
      execute(
        """
        ALTER TABLE token_transfers
        DROP CONSTRAINT token_transfers_pkey,
        ADD PRIMARY KEY (block_hash, log_index);
        """,
        """
        ALTER TABLE token_transfers
        DROP CONSTRAINT token_transfers_pkey,
        ADD PRIMARY KEY (transaction_hash, block_hash, log_index);
        """
      )
    end

    drop_if_exists(index(:internal_transactions, [:from_address_hash]))
  end
end
