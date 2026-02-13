defmodule Explorer.Repo.Migrations.AddInternalTransactionsPkNotNullConstraint do
  use Ecto.Migration

  def change do
    create(
      constraint(:internal_transactions, :internal_transactions_block_number_not_null,
        check: "block_number IS NOT NULL",
        validate: false
      )
    )

    create(
      constraint(:internal_transactions, :internal_transactions_transaction_index_not_null,
        check: "transaction_index IS NOT NULL",
        validate: false
      )
    )
  end
end
