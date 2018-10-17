defmodule Explorer.Repo.Migrations.AddIndexToInternalTransactionTable do
  use Ecto.Migration

  def change do
    create(index("transactions", [:hash]))

    create(
      index("internal_transactions", [
        :to_address_hash,
        :from_address_hash,
        :created_contract_address_hash,
        :type,
        :index
      ])
    )
  end
end
