defmodule Explorer.Chain.Import.Runner.StakingPoolsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.StakingPools
  alias Explorer.Chain.StakingPool

  describe "run/1" do
    test "insert new pools list" do
      pools =
        [pool1, pool2] =
        [params_for(:staking_pool), params_for(:staking_pool)]
        |> Enum.map(fn param ->
          changeset = StakingPool.changeset(%StakingPool{}, param)
          changeset.changes
        end)

      assert {:ok, %{insert_staking_pools: list}} = run_changes(pools)
      assert Enum.count(list) == Enum.count(pools)

      saved_list =
        Explorer.Chain.StakingPool
        |> Repo.all()
        |> Enum.reduce(%{}, fn pool, acc ->
          Map.put(acc, pool.staking_address_hash, pool)
        end)

      assert saved_list[pool1.staking_address_hash].staked_ratio == Decimal.new("50.00")
      assert saved_list[pool2.staking_address_hash].staked_ratio == Decimal.new("50.00")
    end
  end

  defp run_changes(changes) do
    Multi.new()
    |> StakingPools.run(changes, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end
end
