defmodule Explorer.Repo.Migrations.AddLogsPkNotNullConstraint do
  use Ecto.Migration

  def change do
    create(
      constraint(:logs, :logs_block_number_not_null,
        check: "block_number IS NOT NULL",
        validate: false
      )
    )

    create(
      constraint(:logs, :logs_transaction_index_not_null,
        check: "transaction_index IS NOT NULL",
        validate: false
      )
    )
  end
end
