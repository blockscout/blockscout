defmodule Explorer.Repo.Celo.Migrations.RemoveTransactionHashFromPrimaryKeyInLogs do
  use Ecto.Migration

  def change do
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

    execute(
      "ALTER TABLE logs ALTER COLUMN transaction_hash DROP NOT NULL",
      "ALTER TABLE logs ALTER COLUMN transaction_hash SET NOT NULL"
    )

    drop(unique_index(:logs, [:transaction_hash, :index]))
    create_if_not_exists(index(:logs, [:transaction_hash, :index]))
  end
end
