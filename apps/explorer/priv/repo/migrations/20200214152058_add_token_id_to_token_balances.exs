defmodule Explorer.Repo.Migrations.AddTokenIdToTokenBalances do
  use Ecto.Migration

  def change do
    alter table(:address_token_balances) do
      add(:token_id, :numeric, precision: 78, scale: 0, null: true)
      add(:token_type, :string, null: true)
    end

    create(index(:address_token_balances, [:token_id]))
  end
end
