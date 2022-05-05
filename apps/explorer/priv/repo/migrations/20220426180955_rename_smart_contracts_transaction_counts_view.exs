defmodule Explorer.Repo.Migrations.RenameSmartContractsTransactionCountsView do
  use Ecto.Migration

  def up do
    execute("""
    ALTER MATERIALIZED VIEW smart_contract_transaction_counts RENAME TO smart_contracts_transaction_counts;
    """)
  end

  def down do
    execute("""
    ALTER MATERIALIZED VIEW smart_contracts_transaction_counts RENAME TO smart_contract_transaction_counts;
    """)
  end
end
