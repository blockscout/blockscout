defmodule Explorer.Chain.StakingPoolTest do
  use Explorer.DataCase

  alias Explorer.Chain.StakingPool

  describe "changeset/2" do
    test "with valid attributes" do
      params = params_for(:staking_pool)
      changeset = StakingPool.changeset(%StakingPool{}, params)
      assert changeset.valid?
    end

    test "with invalid attributes" do
      changeset = StakingPool.changeset(%StakingPool{}, %{staking_address_hash: 0})
      refute changeset.valid?
    end
  end
end
