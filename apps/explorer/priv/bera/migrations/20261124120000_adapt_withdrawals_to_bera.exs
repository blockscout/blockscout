# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Bera.Migrations.AdaptWithdrawalsToBera do
  @moduledoc """
  Adapts the `withdrawals` table to Berachain withdrawals.

  Berachain consensus client (beacon-kit) puts a synthetic "EVM inflation"
  withdrawal at the first position of every block. It mints the block reward
  and always carries `index` and `validator_index` equal to the max `uint64`
  value. Hence:

  - `index` and `validator_index` are widened to `numeric(20, 0)`, since the
    max `uint64` value fits neither `integer` nor `bigint`;
  - `index` is not unique anymore, so the primary key becomes
    `(block_number, index)`. This requires the new `block_number` column, which
    is also what the withdrawals are ordered by.
  """
  use Ecto.Migration

  def up do
    execute("ALTER TABLE withdrawals DROP CONSTRAINT withdrawals_pkey")

    alter table(:withdrawals) do
      modify(:index, :numeric, precision: 20, scale: 0, null: false)
      modify(:validator_index, :numeric, precision: 20, scale: 0, null: false)
      add(:block_number, :bigint)
    end

    execute("""
    UPDATE withdrawals w
    SET block_number = b.number
    FROM blocks b
    WHERE b.hash = w.block_hash
    """)

    execute("DELETE FROM withdrawals WHERE block_number IS NULL")

    execute("ALTER TABLE withdrawals ALTER COLUMN block_number SET NOT NULL")
    execute("ALTER TABLE withdrawals ADD PRIMARY KEY (block_number, index)")

    create(index(:withdrawals, [:address_hash, :block_number, :index]))
  end

  def down do
    raise Ecto.MigrationError,
      message: "Irreversible migration: withdrawals index is not unique on Bera chain type"
  end
end
