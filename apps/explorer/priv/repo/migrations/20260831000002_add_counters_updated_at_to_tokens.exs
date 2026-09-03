# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.AddCountersUpdatedAtToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:counters_updated_at, :bigint, null: true)
    end
  end
end
