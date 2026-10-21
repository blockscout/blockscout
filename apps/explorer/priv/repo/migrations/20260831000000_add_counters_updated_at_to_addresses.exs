# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.AddCountersUpdatedAtToAddresses do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add(:counters_updated_at, :bigint, null: true)
    end
  end
end
