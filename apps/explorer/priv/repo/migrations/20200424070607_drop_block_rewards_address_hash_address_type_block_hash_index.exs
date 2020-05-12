defmodule Explorer.Repo.Migrations.DropBlockRewardsAddressHashAddressTypeBlockHashIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(:block_rewards, [:address_hash, :block_hash, :address_type],
        name: "block_rewards_address_hash_address_type_block_hash_index"
      )
    )
  end
end
