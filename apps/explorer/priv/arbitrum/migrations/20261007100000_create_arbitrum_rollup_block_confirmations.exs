# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Arbitrum.Migrations.CreateArbitrumRollupBlockConfirmations do
  use Ecto.Migration

  def change do
    create table(:arbitrum_rollup_block_confirmations, primary_key: false) do
      # The rollup block that the `SendRootUpdated` event confirms. The event also
      # confirms all rollup blocks below it. The order of `top` gives the blocks of
      # each row: a row owns the blocks above the `top` of the row below it, up to
      # its own `top`. The lowest row owns the blocks from 0.
      add(:top, :integer, null: false, primary_key: true)

      add(
        :confirmation_id,
        references(:arbitrum_lifecycle_l1_transactions, on_delete: :restrict, on_update: :update_all, type: :integer),
        null: false
      )

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:arbitrum_rollup_block_confirmations, :confirmation_id))
  end
end
