defmodule Explorer.Repo.Migrations.CreateSuggestedIndexes do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:address_token_balances, [:block_number, :address_hash]))
    create_if_not_exists(index(:block_rewards, [:block_hash]))
  end
end
