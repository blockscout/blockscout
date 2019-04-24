defmodule Explorer.Repo.Migrations.AddEarliestProcessingStartToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:earliest_processing_start, :utc_datetime_usec)
    end
  end
end
