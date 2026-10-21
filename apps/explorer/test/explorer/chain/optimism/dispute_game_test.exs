# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Optimism.DisputeGameTest do
  use Explorer.DataCase

  alias Explorer.Chain.Cache.ChainId
  alias Explorer.Chain.Data
  alias Explorer.Chain.Optimism.DisputeGame

  if Application.compile_env(:explorer, :chain_type) == :optimism do
    # game types are taken from `GameTypes` library of the OP Stack contracts
    @cannon_game_type 0
    @permissioned_cannon_game_type 1
    @super_cannon_game_type 4
    @super_permissioned_game_type 5
    @super_asterisc_kona_game_type 7
    @super_cannon_kona_game_type 9
    @zk_dispute_game_type 10

    @l2_block_number 123_456_789
    @l2_timestamp 1_758_000_000

    # `extraData` of a game with Output Root claim: abi.encode(uint256 l2BlockNumber)
    @output_root_extra_data %Data{bytes: <<@l2_block_number::size(256)>>}

    # `extraData` of a game with Super Root claim (see `Encoding.decodeSuperRootProof` in the OP Stack contracts):
    # 1 byte of version, 8 bytes of timestamp, (32 bytes of chain ID + 32 bytes of output root) per chain
    @super_root_extra_data %Data{
      bytes: <<1, @l2_timestamp::size(64), 10::size(256), 0xAA::size(256), 8453::size(256), 0xBB::size(256)>>
    }

    setup do
      ChainId.set_id(10)
      :ok
    end

    describe "super_game_type?/1" do
      test "returns true only for Super Root game types" do
        assert DisputeGame.super_game_type?(@super_cannon_game_type)
        assert DisputeGame.super_game_type?(@super_permissioned_game_type)
        assert DisputeGame.super_game_type?(@super_asterisc_kona_game_type)
        assert DisputeGame.super_game_type?(@super_cannon_kona_game_type)
        assert DisputeGame.super_game_type?(@zk_dispute_game_type)

        refute DisputeGame.super_game_type?(@cannon_game_type)
        refute DisputeGame.super_game_type?(@permissioned_cannon_game_type)
        refute DisputeGame.super_game_type?(nil)
      end
    end

    describe "l2_sequence_number/1" do
      test "returns L2 block number for a game with Output Root claim" do
        game = %{game_type: @cannon_game_type, extra_data: @output_root_extra_data}
        assert DisputeGame.l2_sequence_number(game) == {:block_number, @l2_block_number}
      end

      test "returns L2 timestamp for a game with Super Root claim" do
        for game_type <- [@super_permissioned_game_type, @super_cannon_kona_game_type] do
          game = %{game_type: game_type, extra_data: @super_root_extra_data}
          assert DisputeGame.l2_sequence_number(game) == {:timestamp, @l2_timestamp}
        end
      end

      test "returns zero when extra data is unknown" do
        assert DisputeGame.l2_sequence_number(%{game_type: @cannon_game_type, extra_data: nil}) == {:block_number, 0}

        assert DisputeGame.l2_sequence_number(%{game_type: @super_cannon_kona_game_type, extra_data: nil}) ==
                 {:timestamp, 0}
      end
    end

    describe "l2_block_number_from_extra_data/1" do
      test "returns zero when extra data is shorter than expected" do
        assert DisputeGame.l2_block_number_from_extra_data(%Data{bytes: <<1, 2, 3>>}) == 0
      end
    end

    describe "l2_timestamp_from_extra_data/1" do
      test "parses the timestamp of the Super Root proof" do
        assert DisputeGame.l2_timestamp_from_extra_data(@super_root_extra_data) == @l2_timestamp
      end

      test "returns zero for unsupported Super Root proof version" do
        extra_data = %Data{bytes: <<2, @l2_timestamp::size(64), 10::size(256), 0xAA::size(256)>>}
        assert DisputeGame.l2_timestamp_from_extra_data(extra_data) == 0
      end

      test "returns zero when extra data is shorter than expected" do
        assert DisputeGame.l2_timestamp_from_extra_data(%Data{bytes: <<1, 2, 3>>}) == 0
      end

      test "returns zero when the list of output roots is empty" do
        assert DisputeGame.l2_timestamp_from_extra_data(%Data{bytes: <<1, @l2_timestamp::size(64)>>}) == 0
      end

      test "returns zero when an output root entry is truncated" do
        # 32 bytes of chain ID followed by only 16 bytes of the output root
        extra_data = %Data{bytes: <<1, @l2_timestamp::size(64), 10::size(256), 0xAA::size(128)>>}
        assert DisputeGame.l2_timestamp_from_extra_data(extra_data) == 0

        # one complete entry followed by a truncated one
        extra_data = %Data{
          bytes: <<1, @l2_timestamp::size(64), 10::size(256), 0xAA::size(256), 8453::size(256), 0xBB::size(64)>>
        }

        assert DisputeGame.l2_timestamp_from_extra_data(extra_data) == 0
      end

      test "accepts a single complete output root entry" do
        extra_data = %Data{bytes: <<1, @l2_timestamp::size(64), 10::size(256), 0xAA::size(256)>>}
        assert DisputeGame.l2_timestamp_from_extra_data(extra_data) == @l2_timestamp
      end
    end
  end
end
