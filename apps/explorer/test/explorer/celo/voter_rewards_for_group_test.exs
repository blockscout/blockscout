defmodule Explorer.Celo.VoterRewardsForGroupTest do
  use Explorer.DataCase

  alias Explorer.Celo.VoterRewardsForGroup
  alias Explorer.Celo.ContractEvents.Election.{ValidatorGroupActiveVoteRevokedEvent, ValidatorGroupVoteActivatedEvent}
  alias Explorer.Chain.Hash
  alias Explorer.SetupVoterRewardsTest

  describe "calculate/2" do
    test "returns all rewards for a voter voting for a specific group" do
      {voter_address_1_hash, group_address_hash} = SetupVoterRewardsTest.setup_for_group()

      {:ok, rewards} = VoterRewardsForGroup.calculate(voter_address_1_hash, group_address_hash)

      assert rewards ==
               %{
                 group: group_address_hash,
                 total: 350,
                 rewards: [
                   %{
                     amount: 80,
                     block_hash: %Hash{
                       byte_count: 32,
                       bytes:
                         <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           1>>
                     },
                     block_number: 10_696_320,
                     date: ~U[2022-01-01 17:42:43.162804Z],
                     epoch_number: 619
                   },
                   %{
                     amount: 20,
                     block_hash: %Hash{
                       byte_count: 32,
                       bytes:
                         <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           2>>
                     },
                     block_number: 10_713_600,
                     date: ~U[2022-01-02 17:42:43.162804Z],
                     epoch_number: 620
                   },
                   %{
                     amount: 75,
                     block_hash: %Hash{
                       byte_count: 32,
                       bytes:
                         <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           3>>
                     },
                     block_number: 10_730_880,
                     date: ~U[2022-01-03 17:42:43.162804Z],
                     epoch_number: 621
                   },
                   %{
                     amount: 31,
                     block_hash: %Hash{
                       byte_count: 32,
                       bytes:
                         <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           4>>
                     },
                     block_number: 10_748_160,
                     date: ~U[2022-01-04 17:42:43.162804Z],
                     epoch_number: 622
                   },
                   %{
                     amount: 77,
                     block_hash: %Hash{
                       byte_count: 32,
                       bytes:
                         <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           5>>
                     },
                     block_number: 10_765_440,
                     date: ~U[2022-01-05 17:42:43.162804Z],
                     epoch_number: 623
                   },
                   %{
                     amount: 67,
                     block_hash: %Hash{
                       byte_count: 32,
                       bytes:
                         <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           6>>
                     },
                     block_number: 10_782_720,
                     date: ~U[2022-01-06 17:42:43.162804Z],
                     epoch_number: 624
                   }
                 ]
               }
    end
  end

  describe "amount_activated_or_revoked_last_day/2" do
    test "sums a voter's activated and revoked CELO for the previous day of the block passed" do
      validator_group_vote_activated = ValidatorGroupVoteActivatedEvent.name()
      validator_group_active_vote_revoked = ValidatorGroupActiveVoteRevokedEvent.name()

      voter_activated_or_revoked = [
        %{
          block_hash: %Hash{
            byte_count: 32,
            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
          },
          block_number: 10_692_863,
          amount_activated_or_revoked: 650,
          event: validator_group_vote_activated,
          group_hash: "0x0000000000000000000000000000000000000003",
          voter_hash: "0x0000000000000000000000000000000000000001"
        },
        %{
          block_hash: %Hash{
            byte_count: 32,
            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8>>
          },
          block_number: 10_695_496,
          amount_activated_or_revoked: 650,
          event: validator_group_vote_activated,
          group_hash: "0x0000000000000000000000000000000000000003",
          voter_hash: "0x0000000000000000000000000000000000000001"
        },
        %{
          block_hash: %Hash{
            byte_count: 32,
            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16>>
          },
          block_number: 10_706_524,
          amount_activated_or_revoked: 350,
          event: validator_group_active_vote_revoked,
          group_hash: "0x0000000000000000000000000000000000000003",
          voter_hash: "0x0000000000000000000000000000000000000001"
        },
        %{
          block_hash: %Hash{
            byte_count: 32,
            bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16>>
          },
          block_number: 10_796_524,
          amount_activated_or_revoked: 350,
          event: validator_group_active_vote_revoked,
          group_hash: "0x0000000000000000000000000000000000000003",
          voter_hash: "0x0000000000000000000000000000000000000001"
        }
      ]

      assert VoterRewardsForGroup.amount_activated_or_revoked_last_day(voter_activated_or_revoked, 10_710_000) == 950
    end
  end
end
