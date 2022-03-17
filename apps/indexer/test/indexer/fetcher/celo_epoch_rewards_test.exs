defmodule Indexer.Fetcher.CeloEpochRewardsTest do
  # MUST be `async: false` so that {:shared, pid} is set for connection to allow CoinBalanceFetcher's self-send to have
  # connection allowed immediately.
  use EthereumJSONRPC.Case, async: false
  use Explorer.DataCase

  import Explorer.Celo.CacheHelper
  import Mox

  alias Explorer.Chain.{Block, CeloEpochRewards, CeloPendingEpochOperation, Hash}
  alias Indexer.Fetcher.CeloEpochRewards, as: CeloEpochRewardsFetcher

  @moduletag :capture_log

  # MUST use global mode because we aren't guaranteed to get `start_supervised`'s pid back fast enough to `allow` it to
  # use expectations and stubs from test's pid.
  setup :set_mox_global

  setup :verify_on_exit!

  setup do
    start_supervised!({Task.Supervisor, name: Indexer.TaskSupervisor})

    # Need to always mock to allow consensus switches to happen on demand and protect from them happening when we don't
    # want them to.
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.Mox,
        transport_options: [],
        # Which one does not matter, so pick one
        variant: EthereumJSONRPC.Parity
      ]
    }
  end

  describe "init/2" do
    test "buffers unindexed epoch blocks", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)
      insert(:celo_pending_epoch_operations, block_hash: block.hash, fetch_epoch_rewards: true)

      assert CeloEpochRewardsFetcher.init(
               [],
               fn block_number, acc -> [block_number | acc] end,
               json_rpc_named_arguments
             ) == [%{block_number: block.number, block_hash: block.hash}]
    end

    @tag :no_geth
    test "does not buffer blocks with fetched epoch rewards", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      block = insert(:block)
      insert(:celo_pending_epoch_operations, block_hash: block.hash, fetch_epoch_rewards: false)

      assert CeloEpochRewardsFetcher.init(
               [],
               fn block_number, acc -> [block_number | acc] end,
               json_rpc_named_arguments
             ) == []
    end
  end

  describe "fetch_from_blockchain/1" do
    setup do
      block = insert(:block, number: 172_800)

      %{block: block}
    end

    test "fetches epoch data from blockchain", %{
      block: %Block{
        hash: block_hash,
        number: block_number
      }
    } do
      setup_mox(%{
        id: 0,
        jsonrpc: "2.0",
        result:
          "0x00000000000000000000000000000000000000000000000b25b7389d6e6f8233000000000000000000000000000000000000000000000583d67889a223c1b9ab00000000000000000000000000000000000000000000034b50882b7adf687bd70000000000000000000000000000000000000000000000035f8ddb4f56e8ddad"
      })

      fetched =
        CeloEpochRewardsFetcher.fetch_from_blockchain([
          %{block_number: block_number, block_hash: block_hash}
        ])

      assert [
               %{
                 block_number: block_number,
                 carbon_offsetting_target_epoch_rewards: 62_225_632_760_255_012_269,
                 community_target_epoch_rewards: 15_556_408_190_063_753_067_479,
                 validator_target_epoch_rewards: 205_631_887_959_760_273_971,
                 voter_target_epoch_rewards: 26_043_810_141_454_976_793_003,
                 target_total_supply: 601_017_204_041_941_484_863_859_293,
                 rewards_multiplier: 1_000_741_854_737_500_000_000_000,
                 rewards_multiplier_max: 2_000_000_000_000_000_000_000_000,
                 rewards_multiplier_under: 500_000_000_000_000_000_000_000,
                 rewards_multiplier_over: 5_000_000_000_000_000_000_000_000,
                 target_voting_yield: 160_000_000_000_000_000_000,
                 target_voting_yield_adjustment_factor: 0,
                 target_voting_yield_max: 500_000_000_000_000_000_000,
                 target_voting_fraction: 500_000_000_000_000_000_000_000,
                 voting_fraction: 410_303_431_329_291_024_629_586,
                 total_locked_gold: 316_279_462_377_767_975_674_883_803,
                 total_non_voting: 22_643_903_944_557_354_402_445_358,
                 total_votes: 293_635_558_433_210_621_272_438_445,
                 electable_validators_max: 110,
                 reserve_gold_balance: 115_255_226_249_038_379_930_471_272,
                 gold_total_supply: 600_363_049_982_598_326_620_386_513,
                 stable_usd_total_supply: 5_182_985_086_049_091_467_996_121,
                 block_hash: block_hash,
                 epoch_number: 10
               }
             ] == fetched
    end
  end

  describe "import_items/1" do
    test "saves epoch rewards and deletes celo pending epoch operations" do
      block =
        insert(:block,
          hash: %Hash{
            byte_count: 32,
            bytes:
              <<252, 154, 78, 156, 195, 203, 115, 134, 25, 196, 0, 181, 189, 239, 174, 127, 27, 61, 98, 208, 104, 72,
                127, 167, 112, 119, 204, 138, 81, 255, 5, 91>>
          },
          number: 9_434_880
        )

      insert(:celo_pending_epoch_operations,
        block_hash: block.hash,
        fetch_epoch_rewards: true,
        fetch_validator_group_data: false
      )

      rewards = [
        %{
          address_hash: %Hash{
            byte_count: 20,
            bytes: <<42, 57, 230, 201, 63, 231, 229, 237, 228, 165, 179, 126, 139, 187, 19, 165, 70, 44, 201, 123>>
          },
          block_hash: block.hash,
          block_number: block.number,
          carbon_offsetting_target_epoch_rewards: 55_094_655_441_694_756_188,
          community_target_epoch_rewards: 13_773_663_860_423_689_047_089,
          electable_validators_max: 110,
          epoch_number: 546,
          gold_total_supply: 632_725_491_274_706_367_854_422_889,
          log_index: 0,
          reserve_gold_balance: 115_257_993_782_506_057_885_594_247,
          rewards_multiplier: 830_935_429_083_244_762_116_865,
          rewards_multiplier_max: 2_000_000_000_000_000_000_000_000,
          rewards_multiplier_over: 5_000_000_000_000_000_000_000_000,
          rewards_multiplier_under: 500_000_000_000_000_000_000_000,
          stable_usd_total_supply: 102_072_732_704_065_987_635_855_047,
          target_total_supply: 619_940_889_565_364_451_209_200_067,
          target_voting_fraction: 600_000_000_000_000_000_000_000,
          target_voting_yield: 161_241_419_224_794_107_230,
          target_voting_yield_adjustment_factor: 1_127_990_000_000_000_000,
          target_voting_yield_max: 500_000_000_000_000_000_000,
          total_locked_gold: 316_316_894_443_027_811_324_534_950,
          total_non_voting: 22_643_903_944_557_354_402_445_358,
          total_votes: 293_672_990_498_470_456_922_089_592,
          validator_target_epoch_rewards: 170_740_156_660_940_704_543,
          voter_target_epoch_rewards: 38_399_789_501_591_793_730_548,
          voting_fraction: 567_519_683_693_557_844_261_489
        }
      ]

      CeloEpochRewardsFetcher.import_items(rewards)

      assert count(CeloEpochRewards) == 1
    end
  end

  defp count(schema) do
    Repo.one!(select(schema, fragment("COUNT(*)")))
  end

  defp setup_mox(calculate_target_epoch_rewards_response) do
    set_test_addresses(%{
      "EpochRewards" => "0x07f007d389883622ef8d4d347b3f78007f28d8b7",
      "LockedGold" => "0x6cc083aed9e3ebe302a6336dbc7c921c9f03349e",
      "Election" => "0x8d6677192144292870907e3fa8a5527fe55a7ff6",
      "Reserve" => "0x9380fa34fd9e4fd14c06305fd7b6199089ed4eb9",
      "GoldToken" => "0x471ece3750da237f93b8e339c536989b8978a438",
      "StableToken" => "0x765de816845861e75a25fca122bb6898b8b1282a"
    })

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn [
           %{
             id: _calculateTargetEpochRewards,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x64347043", to: _}, _]
           },
           %{
             id: getTargetGoldTotalSupply,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x5049890f", to: _}, _]
           },
           %{
             id: getRewardsMultiplier,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x0203ab24", to: _}, _]
           },
           %{
             id: getRewardsMultiplierParameters,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x5f396e48", to: _}, _]
           },
           %{
             id: getTargetVotingYieldParameters,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x171af90f", to: _}, _]
           },
           %{
             id: getTargetVotingGoldFraction,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0xae098de2", to: _}, _]
           },
           %{
             id: getVotingGoldFraction,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0xa1b95962", to: _}, _]
           },
           %{
             id: getTotalLockedGold,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x30a61d59", to: _}, _]
           },
           %{
             id: getNonvotingLockedGold,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x807876b7", to: _}, _]
           },
           %{
             id: getTotalVotes,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x9a0e7d66", to: _}, _]
           },
           %{
             id: getElectableValidators,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0xf9f41a7a", to: _}, _]
           },
           %{
             id: getReserveGoldBalance,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x8d9a5e6f", to: _}, _]
           },
           %{
             id: goldTotalSupply,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x18160ddd", to: "0x471ece3750da237f93b8e339c536989b8978a438"}, _]
           },
           %{
             id: stableUSDTotalSupply,
             jsonrpc: "2.0",
             method: "eth_call",
             params: [%{data: "0x18160ddd", to: "0x765de816845861e75a25fca122bb6898b8b1282a"}, _]
           }
         ],
         _ ->
        {
          :ok,
          [
            calculate_target_epoch_rewards_response,
            %{
              id: getTargetGoldTotalSupply,
              jsonrpc: "2.0",
              result: "0x000000000000000000000000000000000000000001f12657ea8a3cbb0ff9aa5d"
            },
            %{
              id: getRewardsMultiplier,
              jsonrpc: "2.0",
              result: "0x00000000000000000000000000000000000000000000d3ea531c462b6d289800"
            },
            %{
              id: getRewardsMultiplierParameters,
              jsonrpc: "2.0",
              result:
                "0x00000000000000000000000000000000000000000001a784379d99db420000000000000000000000000000000000000000000000000069e10de76676d08000000000000000000000000000000000000000000000000422ca8b0a00a425000000"
            },
            %{
              id: getTargetVotingYieldParameters,
              jsonrpc: "2.0",
              result:
                "0x000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000001b1ae4d6e2ef5000000000000000000000000000000000000000000000000000000000000000000000"
            },
            %{
              id: getTargetVotingGoldFraction,
              jsonrpc: "2.0",
              result: "0x0000000000000000000000000000000000000000000069e10de76676d0800000"
            },
            %{
              id: getVotingGoldFraction,
              jsonrpc: "2.0",
              result: "0x0000000000000000000000000000000000000000000056e297f4f13e205a7f52"
            },
            %{
              id: getTotalLockedGold,
              jsonrpc: "2.0",
              result: "0x000000000000000000000000000000000000000001059ec802d92a296076aedb"
            },
            %{
              id: getNonvotingLockedGold,
              jsonrpc: "2.0",
              result: "0x00000000000000000000000000000000000000000012bb087e1546063ebff82e"
            },
            %{
              id: getTotalVotes,
              jsonrpc: "2.0",
              result: "0x000000000000000000000000000000000000000000f2e3bf84c3e42321b6b6ad"
            },
            %{
              id: getElectableValidators,
              jsonrpc: "2.0",
              result:
                "0x0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000006e"
            },
            %{
              id: getReserveGoldBalance,
              jsonrpc: "2.0",
              result: "0x0000000000000000000000000000000000000000005f563e55a0348825d9cb68"
            },
            %{
              id: goldTotalSupply,
              jsonrpc: "2.0",
              result: "0x000000000000000000000000000000000000000001f09bd2274f90dfe61df4d1"
            },
            %{
              id: stableUSDTotalSupply,
              jsonrpc: "2.0",
              result: "0x00000000000000000000000000000000000000000004498a2f3c39c0d4b5ebd9"
            }
          ]
        }
      end
    )
  end
end
