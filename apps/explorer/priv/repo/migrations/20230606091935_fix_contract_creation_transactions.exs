defmodule Explorer.Repo.Migrations.FixContractCreationTransactions do
  use Ecto.Migration

  def change do
    execute("""
      UPDATE addresses a
      SET contract_code = NULL
      FROM transactions t
      WHERE t.created_contract_address_hash IS NOT NULL AND t.created_contract_address_hash = a.hash AND t.to_address_hash IS NOT NULL;
    """)

    execute("""
      UPDATE transactions
      SET created_contract_address_hash = NULL
      WHERE created_contract_address_hash IS NOT NULL AND to_address_hash IS NOT NULL;
    """)
  end
end
