defmodule Explorer.Repo.Migrations.RemoveDuplicateIndexesTokenEntities do
  use Ecto.Migration

  def change do
    drop(index(:address_token_balances, [:block_number]))

    drop(index(:token_instances, [:token_id]))
  end
end
