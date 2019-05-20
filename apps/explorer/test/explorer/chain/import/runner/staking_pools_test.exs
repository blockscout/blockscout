defmodule Explorer.Chain.Import.Runner.StakingPoolsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.StakingPools

  describe "run/1" do
    test "insert new pools list" do
      pools = [pool1, pool2, pool3, pool4] = build_list(4, :staking_pool)

      assert {:ok, %{insert_staking_pools: list}} = run_changes(pools)
      assert Enum.count(list) == Enum.count(pools)

      saved_list =
        Explorer.Chain.Address.Name
        |> Repo.all()
        |> Enum.reduce(%{}, fn pool, acc ->
          Map.put(acc, pool.address_hash, pool)
        end)

      assert saved_list[pool1.address_hash].metadata["staked_ratio"] == 0.25
      assert saved_list[pool2.address_hash].metadata["staked_ratio"] == 0.25
      assert saved_list[pool3.address_hash].metadata["staked_ratio"] == 0.25
      assert saved_list[pool4.address_hash].metadata["staked_ratio"] == 0.25
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
