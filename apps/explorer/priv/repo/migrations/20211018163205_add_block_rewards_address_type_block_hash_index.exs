defmodule Explorer.Repo.Migrations.AddBlockRewardsAddressTypeBlockHashIndex do
  use Ecto.Migration

  def change do
    create(
      index(
        :block_rewards,
        ~w(address_type block_hash)a
      )
    )
  end
end
