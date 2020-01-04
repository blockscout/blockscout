defmodule Explorer.Repo.Migrations.BlockRewardsBlockHashPartialIndex do
  use Ecto.Migration

  def change do
    execute(
      "CREATE INDEX IF NOT EXISTS block_rewards_block_hash_partial_index on block_rewards(block_hash) WHERE address_type='validator';"
    )
  end
end
