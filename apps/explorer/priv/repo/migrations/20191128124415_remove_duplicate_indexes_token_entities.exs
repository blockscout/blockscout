defmodule Explorer.Repo.Migrations.RemoveDuplicateIndexesTokenEntities do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:address_token_balances, [:block_number], name: "address_token_balances_block_number_index"))

    drop_if_exists(index(:token_instances, [:token_id], name: "token_instances_token_id_index"))
  end
end
