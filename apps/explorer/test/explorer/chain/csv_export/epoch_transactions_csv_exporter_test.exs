defmodule Explorer.CSV.Export.EpochTransactionsCsvExporterTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Address, Wei}
  alias Explorer.Celo.CacheHelper

  describe "export/3" do
    test "exports epoch transactions to csv" do
      %Address{hash: celo_address} = insert(:address)
      %Address{hash: cusd_address} = insert(:address)

      CacheHelper.set_test_addresses(%{
        "GoldToken" => to_string(celo_address),
        "StableToken" => to_string(cusd_address)
      })

      to_address = insert(:address)

      %Address{hash: from_address_hash_voter} = insert(:address)
      %Address{hash: from_address_hash_validator} = insert(:address)
      %Address{hash: from_address_hash_group} = insert(:address)

      insert(:celo_account, address: to_address.hash)
      insert(:celo_account, address: from_address_hash_voter)
      insert(:celo_account, address: from_address_hash_validator)
      insert(:celo_account, address: from_address_hash_group)

      ignored_block_before =
        insert(
          :block,
          number: 17_280 * 901,
          timestamp: ~U[2022-10-11T18:53:12.162804Z]
        )

      insert(
        :block,
        number: 17_280 * 901 + 1,
        timestamp: ~U[2022-10-11T18:53:12.162804Z]
      )

      block =
        insert(
          :block,
          number: 17_280 * 902,
          timestamp: ~U[2022-10-12T18:53:12.162804Z]
        )

      block_2 =
        insert(
          :block,
          number: 17_280 * 903,
          timestamp: ~U[2022-10-13T18:53:12.162804Z]
        )

      ignored_block_after =
        insert(
          :block,
          number: 17_280 * 904,
          timestamp: ~U[2022-10-14T18:53:12.162804Z]
        )

      voter_reward =
        insert(
          :celo_election_rewards,
          account_hash: to_address.hash,
          associated_account_hash: from_address_hash_voter,
          block_number: block.number,
          block_hash: block.hash,
          block_timestamp: block.timestamp,
          amount: 123_456_789_012_345_678_901,
          reward_type: "voter"
        )

      insert(
        :celo_account_epoch,
        account_hash: to_address.hash,
        block_hash: block.hash,
        block_number: block.number,
        total_locked_gold: 1_000_000_000_000_000_000_123,
        nonvoting_locked_gold: 122
      )

      # Handling the case where there is no locked/activated gold information for given account/epoch pair
      voter_reward_2 =
        insert(
          :celo_election_rewards,
          account_hash: to_address.hash,
          associated_account_hash: from_address_hash_voter,
          block_number: block_2.number,
          block_timestamp: block_2.timestamp,
          block_hash: block_2.hash,
          amount: 123_456_789_012_345_678_901,
          reward_type: "voter"
        )

      # Inserting another voter rewards, but for block that should not be picked up because of the time range
      insert(
        :celo_election_rewards,
        account_hash: to_address.hash,
        associated_account_hash: from_address_hash_voter,
        block_number: ignored_block_before.number,
        block_timestamp: ignored_block_before.timestamp,
        block_hash: ignored_block_before.hash,
        amount: 123_456_789_012_345_678_901,
        reward_type: "voter"
      )

      insert(
        :celo_election_rewards,
        account_hash: to_address.hash,
        associated_account_hash: from_address_hash_voter,
        block_number: ignored_block_after.number,
        block_timestamp: ignored_block_after.timestamp,
        block_hash: ignored_block_after.hash,
        amount: 123_456_789_012_345_678_901,
        reward_type: "voter"
      )

      validator_reward =
        insert(
          :celo_election_rewards,
          account_hash: to_address.hash,
          associated_account_hash: from_address_hash_validator,
          block_number: block_2.number,
          block_timestamp: block_2.timestamp,
          block_hash: block_2.hash,
          amount: 456_789_012_345_678_901_234,
          reward_type: "validator"
        )

      # Inserting another validator reward with mixed addresses to make sure filtering works
      insert(
        :celo_election_rewards,
        associated_account_hash: to_address.hash,
        account_hash: from_address_hash_validator,
        block_number: block.number,
        block_timestamp: block.timestamp,
        block_hash: block.hash,
        amount: 789_012_345_678_901_234_567,
        reward_type: "validator"
      )

      group_reward =
        insert(
          :celo_election_rewards,
          account_hash: to_address.hash,
          associated_account_hash: from_address_hash_group,
          block_number: block.number,
          block_timestamp: block.timestamp,
          block_hash: block.hash,
          amount: 789_012_345_678_901_234_567,
          reward_type: "group"
        )

      {:ok, csv} = Explorer.Export.CSV.export_epoch_transactions(to_address, "2022-10-12", "2022-10-13", [])

      [result_validator, result_voter_2, result_group, result_voter] =
        csv
        |> Enum.drop(1)
        |> Enum.map(fn [
                         epoch_number,
                         _,
                         block_number,
                         _,
                         timestamp,
                         _,
                         epoch_tx_type,
                         _,
                         validator_address,
                         _,
                         validator_group_address,
                         _,
                         to_address,
                         _,
                         type,
                         _,
                         locked_gold,
                         _,
                         activated_gold,
                         _,
                         value,
                         _,
                         value_wei,
                         _,
                         tx_currency,
                         _,
                         tx_currency_contract_address,
                         _
                       ] ->
          %{
            epoch_number: epoch_number,
            block_number: block_number,
            timestamp: timestamp,
            epoch_tx_type: epoch_tx_type,
            validator_address: validator_address,
            validator_group_address: validator_group_address,
            to_address: to_address,
            tx_currency: tx_currency,
            tx_currency_contract_address: tx_currency_contract_address,
            type: type,
            locked_gold: locked_gold,
            activated_gold: activated_gold,
            value: value,
            value_wei: value_wei
          }
        end)

      assert result_voter.epoch_number == [[], "902"]
      assert result_voter.block_number == [[], to_string(block.number)]
      assert result_voter.timestamp == [[], to_string(voter_reward.block_timestamp)]
      assert result_voter.epoch_tx_type == [[], "Voter Rewards"]
      assert result_voter.validator_address == [[], "N/A"]
      assert result_voter.validator_group_address == [[], from_address_hash_voter |> normalize_address()]
      assert result_voter.to_address == [[], to_address.hash |> normalize_address()]
      assert result_voter.tx_currency == [[], "CELO"]
      assert result_voter.tx_currency_contract_address == [[], celo_address |> normalize_address()]
      assert result_voter.type == [[], "IN"]
      assert result_voter.locked_gold == [[], "1000.000000000000000123"]
      assert result_voter.activated_gold == [[], "1000.000000000000000001"]
      assert result_voter.value == [[], to_string(voter_reward.amount |> Wei.to(:ether))]
      assert result_voter.value_wei == [[], to_string(voter_reward.amount)]

      assert result_voter_2.epoch_number == [[], "903"]
      assert result_voter_2.block_number == [[], to_string(block_2.number)]
      assert result_voter_2.timestamp == [[], to_string(voter_reward_2.block_timestamp)]
      assert result_voter_2.epoch_tx_type == [[], "Voter Rewards"]
      assert result_voter_2.validator_address == [[], "N/A"]
      assert result_voter_2.validator_group_address == [[], from_address_hash_voter |> normalize_address()]
      assert result_voter_2.to_address == [[], to_address.hash |> normalize_address()]
      assert result_voter_2.tx_currency == [[], "CELO"]
      assert result_voter_2.tx_currency_contract_address == [[], celo_address |> normalize_address()]
      assert result_voter_2.type == [[], "IN"]
      assert result_voter_2.locked_gold == [[], "unknown"]
      assert result_voter_2.activated_gold == [[], "unknown"]
      assert result_voter_2.value == [[], to_string(voter_reward.amount |> Wei.to(:ether))]
      assert result_voter_2.value_wei == [[], to_string(voter_reward.amount)]

      assert result_validator.epoch_number == [[], "903"]
      assert result_validator.block_number == [[], to_string(block_2.number)]
      assert result_validator.timestamp == [[], to_string(validator_reward.block_timestamp)]
      assert result_validator.epoch_tx_type == [[], "Validator Rewards"]
      assert result_validator.validator_address == [[], "N/A"]
      assert result_validator.validator_group_address == [[], from_address_hash_validator |> normalize_address()]
      assert result_validator.to_address == [[], to_address.hash |> normalize_address()]
      assert result_validator.tx_currency == [[], "cUSD"]
      assert result_validator.tx_currency_contract_address == [[], cusd_address |> normalize_address()]
      assert result_validator.type == [[], "IN"]
      assert result_validator.locked_gold == [[], "N/A"]
      assert result_validator.activated_gold == [[], "N/A"]
      assert result_validator.value == [[], to_string(validator_reward.amount |> Wei.to(:ether))]
      assert result_validator.value_wei == [[], to_string(validator_reward.amount)]

      assert result_group.epoch_number == [[], "902"]
      assert result_group.block_number == [[], to_string(block.number)]
      assert result_group.timestamp == [[], to_string(group_reward.block_timestamp)]
      assert result_group.epoch_tx_type == [[], "Validator Group Rewards"]
      assert result_group.validator_address == [[], from_address_hash_group |> normalize_address()]
      assert result_group.validator_group_address == [[], "N/A"]
      assert result_group.to_address == [[], to_address.hash |> normalize_address()]
      assert result_group.tx_currency == [[], "cUSD"]
      assert result_group.tx_currency_contract_address == [[], cusd_address |> normalize_address()]
      assert result_group.type == [[], "IN"]
      assert result_validator.locked_gold == [[], "N/A"]
      assert result_validator.activated_gold == [[], "N/A"]
      assert result_group.value == [[], to_string(group_reward.amount |> Wei.to(:ether))]
      assert result_group.value_wei == [[], to_string(group_reward.amount)]
    end
  end

  defp normalize_address(address), do: address |> to_string() |> String.downcase()
end
