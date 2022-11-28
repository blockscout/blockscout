defmodule Explorer.Chain.CeloElectionRewardsTest do
  use Explorer.DataCase

  import Explorer.Factory

  alias Explorer.Chain
  alias Explorer.Chain.Wei

  alias Chain.{Address, Block, CeloAccount, CeloElectionRewards}

  describe "get_rewards/2" do
    test "returns rewards for an account that has both voter and validator rewards" do
      %Address{hash: account_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)
      %CeloAccount{name: group_name} = insert(:celo_account, address: group_hash)
      %Block{number: block_number, timestamp: block_timestamp, hash: block_hash} = insert(:block, number: 17_280)

      insert(
        :celo_election_rewards,
        account_hash: account_hash,
        associated_account_hash: group_hash,
        block_number: block_number,
        block_timestamp: block_timestamp,
        block_hash: block_hash
      )

      insert(
        :celo_election_rewards,
        account_hash: account_hash,
        associated_account_hash: group_hash,
        block_number: block_number,
        block_timestamp: block_timestamp,
        block_hash: block_hash,
        reward_type: "validator"
      )

      {:ok, one_wei} = Wei.cast(1)
      {:ok, two_wei} = Wei.cast(2)

      expected_rewards = [
        %{
          account_hash: account_hash,
          amount: one_wei,
          associated_account_name: group_name,
          associated_account_hash: group_hash,
          block_number: block_number,
          date: block_timestamp,
          epoch_number: 1,
          reward_type: "validator"
        },
        %{
          account_hash: account_hash,
          amount: one_wei,
          associated_account_name: group_name,
          associated_account_hash: group_hash,
          block_number: block_number,
          date: block_timestamp,
          epoch_number: 1,
          reward_type: "voter"
        }
      ]

      from = DateTime.add(DateTime.now!("Etc/UTC"), -10)
      to = DateTime.add(DateTime.now!("Etc/UTC"), 10)

      assert CeloElectionRewards.get_rewards([account_hash], ["voter", "validator"], from, to) == %{
               rewards: expected_rewards,
               total_reward_celo: two_wei,
               from: from,
               to: to
             }
    end

    test "returns rewards for a voter for given time frame" do
      %Address{hash: account_hash} = insert(:address)
      %Address{hash: group_hash} = insert(:address)
      %CeloAccount{name: group_name} = insert(:celo_account, address: group_hash)

      %Block{number: block_1_number, hash: block_1_hash, timestamp: block_1_timestamp} =
        insert(:block, number: 17_280, timestamp: ~U[2021-04-20 16:00:00.000000Z])

      %Block{number: block_2_number, hash: block_2_hash, timestamp: block_2_timestamp} =
        insert(:block, number: 17_280 * 2, timestamp: ~U[2021-04-21 16:00:00.000000Z])

      %Block{number: block_3_number, hash: block_3_hash, timestamp: block_3_timestamp} =
        insert(:block, number: 17_280 * 4, timestamp: ~U[2021-04-23 16:00:00.000000Z])

      insert(
        :celo_election_rewards,
        account_hash: account_hash,
        associated_account_hash: group_hash,
        block_number: block_1_number,
        block_timestamp: block_1_timestamp,
        block_hash: block_1_hash
      )

      insert(
        :celo_election_rewards,
        account_hash: account_hash,
        associated_account_hash: group_hash,
        block_number: block_2_number,
        block_timestamp: block_2_timestamp,
        block_hash: block_2_hash
      )

      insert(
        :celo_election_rewards,
        account_hash: account_hash,
        associated_account_hash: group_hash,
        block_number: block_3_number,
        block_timestamp: block_3_timestamp,
        block_hash: block_3_hash
      )

      {:ok, one_wei} = Wei.cast(1)

      expected_rewards = [
        %{
          account_hash: account_hash,
          amount: one_wei,
          associated_account_name: group_name,
          associated_account_hash: group_hash,
          block_number: block_2_number,
          date: block_2_timestamp,
          epoch_number: 2,
          reward_type: "voter"
        }
      ]

      from = ~U[2021-04-21 00:00:00.000000Z]
      to = ~U[2021-04-22 00:00:00.000000Z]

      assert CeloElectionRewards.get_rewards(
               [account_hash],
               ["voter", "validator"],
               from,
               to
             ) == %{from: from, to: to, rewards: expected_rewards, total_reward_celo: one_wei}
    end
  end
end
