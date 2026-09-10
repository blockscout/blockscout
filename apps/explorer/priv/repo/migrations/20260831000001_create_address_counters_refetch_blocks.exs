# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.CreateAddressCountersRefetchBlocks do
  use Ecto.Migration

  def change do
    create table(:address_counters_refetch_blocks, primary_key: false) do
      add(:block_number, :bigint, primary_key: true)

      timestamps(null: false, type: :utc_datetime_usec)
    end
  end
end
