defmodule Explorer.Celo.VoterRewardsTest do
  use Explorer.DataCase

  alias Explorer.Celo.VoterRewards
  alias Explorer.SetupVoterRewardsTest

  describe "calculate/1" do
    test "returns all rewards for a voter" do
      {voter_1_hash, group_1_hash, group_2_hash} = SetupVoterRewardsTest.setup_for_all_groups()

      {:ok, rewards} =
        VoterRewards.calculate(
          voter_1_hash,
          ~U[2022-01-03 00:00:00.000000Z],
          ~U[2022-01-06 00:00:00.000000Z]
        )

      assert rewards ==
               %{
                 total_reward_celo: 300,
                 account: voter_1_hash,
                 from: ~U[2022-01-03 00:00:00.000000Z],
                 to: ~U[2022-01-06 00:00:00.000000Z],
                 rewards: [
                   %{
                     amount: 75,
                     date: ~U[2022-01-03 17:42:43.162804Z],
                     block_number: 10_730_880,
                     block_hash: %Explorer.Chain.Hash{
                       byte_count: 32,
                       bytes:
                         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           3>>
                     },
                     epoch_number: 621,
                     group: group_1_hash
                   },
                   %{
                     amount: 31,
                     date: ~U[2022-01-04 17:42:43.162804Z],
                     block_number: 10_748_160,
                     block_hash: %Explorer.Chain.Hash{
                       byte_count: 32,
                       bytes:
                         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           4>>
                     },
                     epoch_number: 622,
                     group: group_1_hash
                   },
                   %{
                     amount: 77,
                     date: ~U[2022-01-05 17:42:43.162804Z],
                     block_number: 10_765_440,
                     block_hash: %Explorer.Chain.Hash{
                       byte_count: 32,
                       bytes:
                         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           5>>
                     },
                     epoch_number: 623,
                     group: group_1_hash
                   },
                   %{
                     amount: 39,
                     date: ~U[2022-01-04 17:42:43.162804Z],
                     block_number: 10_748_160,
                     block_hash: %Explorer.Chain.Hash{
                       byte_count: 32,
                       bytes:
                         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           4>>
                     },
                     epoch_number: 622,
                     group: group_2_hash
                   },
                   %{
                     amount: 78,
                     date: ~U[2022-01-05 17:42:43.162804Z],
                     block_number: 10_765_440,
                     block_hash: %Explorer.Chain.Hash{
                       byte_count: 32,
                       bytes:
                         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           5>>
                     },
                     epoch_number: 623,
                     group: group_2_hash
                   }
                 ]
               }
    end
  end
end
