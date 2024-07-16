defmodule Explorer.Repo.Migrations.AddBlockTimestampAndConsensusToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add_if_not_exists(:block_timestamp, :utc_datetime_usec)
      add_if_not_exists(:block_consensus, :boolean, default: true)
    end

    create_if_not_exists(index(:transactions, :block_timestamp))
    create_if_not_exists(index(:transactions, :block_consensus))
  end
end
