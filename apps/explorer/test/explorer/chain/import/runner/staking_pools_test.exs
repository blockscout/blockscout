defmodule Explorer.Chain.Import.Runner.StakingPoolsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.StakingPools
  alias Explorer.Chain.StakingPool

  describe "run/1" do
    test "insert new pools list" do
      pools =
        [_pool1, _pool2] =
        [params_for(:staking_pool), params_for(:staking_pool)]
        |> Enum.map(fn param ->
          changeset = StakingPool.changeset(%StakingPool{}, param)
          changeset.changes
        end)

      assert {:ok, %{insert_staking_pools: list}} = run_changes(pools)
      assert Enum.count(list) == Enum.count(pools)
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
