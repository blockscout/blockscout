defmodule Explorer.Celo.VoterRewardsForGroupTest do
  use Explorer.DataCase

  alias Explorer.Celo.VoterRewardsForGroup
  alias Explorer.Chain.{Hash, Wei}
  alias Explorer.SetupVoterRewardsTest

  describe "calculate/2" do
    # to be changed by Vasileios in upcoming PR
    @tag :skip
    test "returns all rewards for a voter voting for a specific group" do
      {
        voter_hash,
        group_hash,
        block_2_hash,
        block_3_hash,
        block_5_hash,
        block_7_hash
      } = SetupVoterRewardsTest.setup_for_group()

      {:ok, rewards} = VoterRewardsForGroup.calculate(voter_hash, group_hash)

      assert rewards ==
               %{
                 group: group_hash,
                 total: 175,
                 rewards: [
                   %{
                     amount: 80,
                     block_hash: block_2_hash,
                     block_number: 10_696_320,
                     date: ~U[2022-01-01 17:42:43.162804Z],
                     epoch_number: 619
                   },
                   %{
                     amount: 20,
                     block_hash: block_3_hash,
                     block_number: 10_713_600,
                     date: ~U[2022-01-02 17:42:43.162804Z],
                     epoch_number: 620
                   },
                   %{
                     amount: 75,
                     block_hash: block_5_hash,
                     block_number: 10_730_880,
                     date: ~U[2022-01-03 17:42:43.162804Z],
                     epoch_number: 621
                   },
                   %{
                     amount: 0,
                     block_hash: block_7_hash,
                     block_number: 10_748_160,
                     date: ~U[2022-01-04 17:42:43.162804Z],
                     epoch_number: 622
                   }
                 ]
               }
    end
  end

  describe "merge_events_with_votes_and_chunk_by_epoch/2" do
    test "when voter first activated on an epoch block" do
      # Block hash is irrelevant in the context of the test so the same one is used everywhere for readability
      block_hash = %Hash{
        byte_count: 32,
        bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
      }

      events = [
        %{
          amount_activated_or_revoked: 650,
          block_hash: block_hash,
          block_number: 618 * 17_280,
          event: "ValidatorGroupVoteActivated"
        },
        %{
          amount_activated_or_revoked: 650,
          block_hash: block_hash,
          block_number: 618 * 17_280 + 1,
          event: "ValidatorGroupActiveVoteRevoked"
        },
        %{
          amount_activated_or_revoked: 250,
          block_hash: block_hash,
          block_number: 621 * 17_280 - 1,
          event: "ValidatorGroupVoteActivated"
        },
        %{
          amount_activated_or_revoked: 1075,
          block_hash: block_hash,
          block_number: 622 * 17_280 - 1,
          event: "ValidatorGroupActiveVoteRevoked"
        }
      ]

      votes = [
        %{
          block_hash: block_hash,
          block_number: 619 * 17_280,
          date: ~U[2022-01-01 17:42:43.162804Z],
          votes: %Wei{value: 730}
        },
        %{
          block_hash: block_hash,
          block_number: 620 * 17_280,
          date: ~U[2022-01-02 17:42:43.162804Z],
          votes: %Wei{value: 750}
        },
        %{
          block_hash: block_hash,
          block_number: 621 * 17_280,
          date: ~U[2022-01-03 17:42:43.162804Z],
          votes: %Wei{value: 1075}
        },
        %{
          block_hash: block_hash,
          block_number: 622 * 17_280,
          date: ~U[2022-01-04 17:42:43.162804Z],
          votes: %Wei{value: 0}
        }
      ]

      assert VoterRewardsForGroup.merge_events_with_votes_and_chunk_by_epoch(events, votes) == [
               [
                 %{
                   amount_activated_or_revoked: 650,
                   block_hash: block_hash,
                   block_number: 618 * 17_280,
                   event: "ValidatorGroupVoteActivated"
                 },
                 %{
                   amount_activated_or_revoked: 650,
                   block_hash: block_hash,
                   block_number: 618 * 17_280 + 1,
                   event: "ValidatorGroupActiveVoteRevoked"
                 },
                 %{
                   block_hash: block_hash,
                   block_number: 619 * 17_280,
                   date: ~U[2022-01-01 17:42:43.162804Z],
                   votes: %Wei{value: 730}
                 }
               ],
               [
                 %{
                   block_hash: block_hash,
                   block_number: 620 * 17_280,
                   date: ~U[2022-01-02 17:42:43.162804Z],
                   votes: %Wei{value: 750}
                 }
               ],
               [
                 %{
                   amount_activated_or_revoked: 250,
                   block_hash: block_hash,
                   block_number: 621 * 17_280 - 1,
                   event: "ValidatorGroupVoteActivated"
                 },
                 %{
                   block_hash: block_hash,
                   block_number: 621 * 17_280,
                   date: ~U[2022-01-03 17:42:43.162804Z],
                   votes: %Wei{value: 1075}
                 }
               ],
               [
                 %{
                   amount_activated_or_revoked: 1075,
                   block_hash: block_hash,
                   block_number: 622 * 17_280 - 1,
                   event: "ValidatorGroupActiveVoteRevoked"
                 },
                 %{
                   block_hash: block_hash,
                   block_number: 622 * 17_280,
                   date: ~U[2022-01-04 17:42:43.162804Z],
                   votes: %Wei{value: 0}
                 }
               ]
             ]
    end
  end
end
