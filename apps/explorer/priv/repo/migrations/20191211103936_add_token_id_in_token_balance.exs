defmodule Explorer.Repo.Migrations.AddTokenIdInTokenBalance do
  use Ecto.Migration

  def change do
    alter table(:address_token_balances) do
      add(:token_id, :bigint)
    end
  end

  def change do
    alter table(:address_current_token_balances) do
      add(:token_id, :bigint)
    end
  end
end
