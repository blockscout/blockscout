defmodule Explorer.Chain.StakingPoolsDelegatorsTest do
  use Explorer.DataCase

  alias Explorer.Chain.StakingPoolsDelegators

  describe "changeset/2" do
    test "with valid attributes" do
      params = params_for(:staking_pools_delegators)
      changeset = StakingPoolsDelegators.changeset(%StakingPoolsDelegators{}, params)
      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = StakingPoolsDelegators.changeset(%StakingPoolsDelegators{}, %{pool_address_hash: 0})
      refute changeset.valid?
    end
  end
end
