defmodule Explorer.Celo.ValidatorGroupRewardsTest do
  use Explorer.DataCase

  alias Explorer.Celo.ValidatorGroupRewards
  alias Explorer.SetupValidatorAndGroupRewardsTest

  describe "calculate/1" do
    test "returns all rewards for a validator group" do
      {validator_address_1_hash, group_address_1_hash, block_2_hash, block_3_hash} =
        SetupValidatorAndGroupRewardsTest.setup()

      {:ok, rewards} =
        ValidatorGroupRewards.calculate(
          group_address_1_hash,
          ~U[2022-01-03 00:00:00.000000Z],
          ~U[2022-01-06 00:00:00.000000Z]
        )

      assert rewards ==
               %{
                 total_reward_celo: 700_000,
                 from: ~U[2022-01-03 00:00:00.000000Z],
                 group: group_address_1_hash,
                 to: ~U[2022-01-06 00:00:00.000000Z],
                 rewards: [
                   %{
                     amount: 300_000,
                     date: ~U[2022-01-03 17:42:43.162804Z],
                     block_number: 10_730_880,
                     block_hash: block_2_hash,
                     epoch_number: 621,
                     validator: validator_address_1_hash
                   },
                   %{
                     amount: 400_000,
                     date: ~U[2022-01-04 17:42:43.162804Z],
                     block_number: 10_748_160,
                     block_hash: block_3_hash,
                     epoch_number: 622,
                     validator: validator_address_1_hash
                   }
                 ]
               }
    end
  end
end
