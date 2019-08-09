defmodule Explorer.Repo.Migrations.RemoveDuplicateIndexes do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(:decompiled_smart_contracts, [:address_hash], name: "decompiled_smart_contracts_address_hash_index")
    )

    drop_if_exists(
      index(:staking_pools_delegators, [:delegator_address_hash],
        name: "staking_pools_delegators_delegator_address_hash_index"
      )
    )

    drop_if_exists(index(:transactions, [:to_address_hash], name: "transactions_to_address_hash_index"))
  end
end
