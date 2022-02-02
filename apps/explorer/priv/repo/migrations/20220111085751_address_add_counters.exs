defmodule Explorer.Repo.Migrations.AddressAddCounters do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add(:transactions_count, :integer, null: true)
      add(:token_transfers_count, :integer, null: true)
    end
  end
end
