# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Eden.Migrations.AddEdenTransactionFields do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:fee_payer_address_hash, :bytea, null: true)
      add(:calls, :jsonb, null: true)
    end
  end
end
