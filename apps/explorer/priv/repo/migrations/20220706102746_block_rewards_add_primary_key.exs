defmodule Explorer.Repo.Migrations.BlockRewardsAddPrimaryKey do
  use Ecto.Migration

  def change do
    drop(
      unique_index(
        :block_rewards,
        ~w(address_hash block_hash address_type)a
      )
    )

    alter table(:block_rewards) do
      modify(:address_hash, :bytea, null: false, primary_key: true)
      modify(:block_hash, :bytea, null: false, primary_key: true)
      modify(:address_type, :string, null: false, primary_key: true)
    end
  end
end
