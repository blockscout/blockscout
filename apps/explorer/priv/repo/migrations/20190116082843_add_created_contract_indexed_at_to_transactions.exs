defmodule Explorer.Repo.Migrations.AddCreatedContractIndexedAtToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      # `null` when `internal_transactions` has never been fetched
      add(:created_contract_code_indexed_at, :utc_datetime_usec, null: true)
    end
  end
end
