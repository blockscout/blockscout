defmodule Explorer.Repo.Migrations.AddBlockRewardsAddressTypeBlockHashIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(
        :public.block_rewards,
        ~w(address_type block_hash)a,
        concurrently: true
      )
    )
  end
end
