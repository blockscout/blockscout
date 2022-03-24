defmodule Explorer.Celo.ValidatorRewards do
  @moduledoc """
    Module responsible for calculating a validator's rewards for a given time frame.
  """
  import Explorer.Celo.Util,
    only: [
      add_input_account_to_individual_rewards_and_calculate_sum: 2,
      fetch_and_structure_rewards: 4
    ]

  def calculate(validator_address_hash, from_date, to_date) do
    res = fetch_and_structure_rewards(validator_address_hash, from_date, to_date, "validator")

    res
    |> then(fn {rewards, total} ->
      %{
        account: validator_address_hash,
        from: from_date,
        rewards: Enum.map(rewards, &Map.delete(&1, :validator)),
        to: to_date,
        total_reward_celo: total
      }
    end)
  end

  def calculate_multiple_accounts(voter_address_hash_list, from_date, to_date) do
    reward_lists_chunked_by_account =
      voter_address_hash_list
      |> Enum.map(fn hash -> calculate(hash, from_date, to_date) end)

    {rewards, rewards_sum} =
      add_input_account_to_individual_rewards_and_calculate_sum(reward_lists_chunked_by_account, :account)

    %{from: from_date, to: to_date, rewards: rewards, total_reward_celo: rewards_sum}
  end
end
