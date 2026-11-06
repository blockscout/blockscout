# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Repo.Migrations.AddMetadataRefetchToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add(:metadata_retries_count, :integer, null: false, default: 0)
      add(:metadata_refetch_after, :utc_datetime_usec, null: true)
    end
  end
end
