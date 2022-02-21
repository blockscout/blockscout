defmodule Explorer.Repo.Migrations.AddFetchValidatorGroupDataToCeloPendingEpochOperations do
  use Ecto.Migration

  def change do
    alter table(:celo_pending_epoch_operations) do
      add(:fetch_validator_group_data, :boolean)
    end
  end
end
