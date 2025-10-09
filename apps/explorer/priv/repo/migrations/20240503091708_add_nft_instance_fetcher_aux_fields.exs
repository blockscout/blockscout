defmodule Explorer.Repo.Migrations.AddNftInstanceFetcherAuxFields do
  use Ecto.Migration

  def change do
    alter table(:token_instances) do
      add(:refetch_after, :utc_datetime_usec, null: true)
      add(:retries_count, :smallint, default: 0, null: false)
    end
  end
end
