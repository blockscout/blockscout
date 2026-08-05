# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Celo.Migrations.RemoveTransactionIndexNotNullConstraintFromLogs do
  use Ecto.Migration

  def up do
    drop_if_exists(constraint(:logs, :logs_transaction_index_not_null))
  end

  def down do
    create(
      constraint(:logs, :logs_transaction_index_not_null,
        check: "transaction_index IS NOT NULL",
        validate: false
      )
    )
  end
end
