defmodule Explorer.Chain.Import.Runner.StakingPoolsDelegatorsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Ecto.Multi
  alias Explorer.Chain.Import.Runner.StakingPoolsDelegators
  alias Explorer.Chain.StakingPoolsDelegator

  describe "run/1" do
    test "insert new pools list" do
      delegators =
        [params_for(:staking_pools_delegator), params_for(:staking_pools_delegator)]
        |> Enum.map(fn param ->
          changeset = StakingPoolsDelegator.changeset(%StakingPoolsDelegator{}, param)
          changeset.changes
        end)

      assert {:ok, %{insert_staking_pools_delegators: list}} = run_changes(delegators)
      assert Enum.count(list) == Enum.count(delegators)
    end
  end

  defp run_changes(changes) do
    Multi.new()
    |> StakingPoolsDelegators.run(changes, %{
      timeout: :infinity,
      timestamps: %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    })
    |> Repo.transaction()
  end
end
