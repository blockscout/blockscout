defmodule Explorer.Repo.Migrations.AlterInternalTransactionsDropConstraint do
  use Ecto.Migration

  def change do
    execute("""
    ALTER table internal_transactions
    DROP CONSTRAINT internal_transactions_pkey,
    ADD PRIMARY KEY (transaction_hash, index) DEFERRABLE;
    """)
  end
end
