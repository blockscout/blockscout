defmodule Explorer.Repo.Migrations.DropBlockRewardsBlockHashPartialIndex do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(
        :block_rewadrs,
        ~w(block_hash)a,
        name: :block_rewards_block_hash_partial_index,
        where: "address_type='validator'"
      )
    )
  end
end
