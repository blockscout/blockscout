defmodule Explorer.Celo.EpochUtilTest do
  use ExUnit.Case
  alias Explorer.Celo.EpochUtil

  describe "epoch_by_block_number/1" do
    test "returns the epoch number when passed a block number" do
      assert EpochUtil.epoch_by_block_number(3_878_389) == 224
    end
  end
end
