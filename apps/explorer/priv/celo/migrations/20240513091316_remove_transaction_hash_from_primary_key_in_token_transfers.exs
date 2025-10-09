defmodule Explorer.Repo.Celo.Migrations.RemoveTransactionHashFromPrimaryKeyInTokenTransfers do
  use Ecto.Migration

  def change do
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

    execute(
      "ALTER TABLE token_transfers ALTER COLUMN transaction_hash DROP NOT NULL",
      "ALTER TABLE token_transfers ALTER COLUMN transaction_hash SET NOT NULL"
    )
  end
end
