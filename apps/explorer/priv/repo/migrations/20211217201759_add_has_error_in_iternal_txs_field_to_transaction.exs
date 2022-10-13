defmodule Explorer.Repo.Migrations.AddHasErrorInInternalTxsFieldToTransaction do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:has_error_in_internal_txs, :boolean, null: true)
    end
  end
end
