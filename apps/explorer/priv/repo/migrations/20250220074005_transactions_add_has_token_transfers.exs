defmodule Explorer.Repo.Migrations.TransactionsAddHasTokenTransfers do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:has_token_transfers, :boolean, null: true)
    end
  end
end
