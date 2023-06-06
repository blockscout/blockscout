defmodule Explorer.Repo.Migrations.FixContractCreationTransactions do
  use Ecto.Migration

  def change do
    execute("""
      UPDATE transactions
      SET created_contract_address_hash = NULL
      WHERE created_contract_address_hash IS NOT NULL AND to_address_hash IS NOT NULL;
    """)
  end
end
