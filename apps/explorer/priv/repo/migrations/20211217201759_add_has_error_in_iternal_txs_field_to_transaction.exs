defmodule Explorer.Repo.Migrations.AddHasErrorInIternalTxsFieldToTransaction do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:has_error_in_iternal_txs, :boolean, null: true)
    end
  end
end
