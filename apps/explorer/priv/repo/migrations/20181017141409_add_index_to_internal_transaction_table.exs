defmodule Explorer.Repo.Migrations.AddIndexToInternalTransactionTable do
  use Ecto.Migration

  def change do
    create(
      index("internal_transactions", [
        :to_address_hash,
        :from_address_hash,
        :created_contract_address_hash,
        :type,
        :index
      ])
    )

    create(index(:internal_transactions, ["block_number DESC, transaction_index DESC, index DESC"]))
  end
end
