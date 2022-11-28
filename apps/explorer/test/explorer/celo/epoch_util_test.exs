defmodule Explorer.Celo.EpochUtilTest do
  use ExUnit.Case
  alias Explorer.Celo.EpochUtil

  describe "epoch_by_block_number/1" do
    test "returns the epoch number when passed a block number" do
      assert EpochUtil.epoch_by_block_number(3_878_389) == 224
    end
  end

  describe "round_to_closest_epoch_block_number/2" do
    test "returns block number rounded up" do
      assert EpochUtil.round_to_closest_epoch_block_number(1, :up) == 17_280
      assert EpochUtil.round_to_closest_epoch_block_number(17_280, :up) == 17_280
      assert EpochUtil.round_to_closest_epoch_block_number(15_793_920, :up) == 15_793_920
      assert EpochUtil.round_to_closest_epoch_block_number(15_793_919, :up) == 15_793_920
      assert EpochUtil.round_to_closest_epoch_block_number(15_793_921, :up) == 15_811_200
    end

    test "returns block number rounded down" do
      assert EpochUtil.round_to_closest_epoch_block_number(1, :down) == 17_280
      assert EpochUtil.round_to_closest_epoch_block_number(17_280, :down) == 17_280
      assert EpochUtil.round_to_closest_epoch_block_number(15_793_920, :down) == 15_793_920
      assert EpochUtil.round_to_closest_epoch_block_number(15_793_919, :down) == 15_776_640
      assert EpochUtil.round_to_closest_epoch_block_number(15_793_921, :down) == 15_793_920
    end
  end
end
