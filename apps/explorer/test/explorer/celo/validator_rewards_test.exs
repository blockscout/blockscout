defmodule Explorer.Celo.ValidatorRewardsTest do
  use Explorer.DataCase

  alias Explorer.Celo.ValidatorRewards
  alias Explorer.SetupValidatorAndGroupRewardsTest

  describe "calculate/1" do
    test "returns all rewards for a validator" do
      {validator_address_1_hash, group_address_1_hash, block_2_hash, block_3_hash} =
        SetupValidatorAndGroupRewardsTest.setup()

      {:ok, rewards} =
        ValidatorRewards.calculate(
          validator_address_1_hash,
          ~U[2022-01-03 00:00:00.000000Z],
          ~U[2022-01-06 00:00:00.000000Z]
        )

      assert rewards ==
               %{
                 total_reward_celo: 300_000,
                 account: validator_address_1_hash,
                 from: ~U[2022-01-03 00:00:00.000000Z],
                 to: ~U[2022-01-06 00:00:00.000000Z],
                 rewards: [
                   %{
                     amount: 100_000,
                     date: ~U[2022-01-03 17:42:43.162804Z],
                     block_number: 10_730_880,
                     block_hash: block_2_hash,
                     epoch_number: 621,
                     group: group_address_1_hash
                   },
                   %{
                     amount: 200_000,
                     date: ~U[2022-01-04 17:42:43.162804Z],
                     block_number: 10_748_160,
                     block_hash: block_3_hash,
                     epoch_number: 622,
                     group: group_address_1_hash
                   }
                 ]
               }
    end
  end
end
