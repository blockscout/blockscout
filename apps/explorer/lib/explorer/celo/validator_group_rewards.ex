defmodule Explorer.Celo.ValidatorGroupRewards do
  @moduledoc """
    Module responsible for calculating a validator's rewards for a given time frame.
  """
  import Explorer.Celo.Util,
    only: [
      add_input_account_to_individual_rewards_and_calculate_sum: 2,
      fetch_and_structure_rewards: 4
    ]

  def calculate(group_address_hash, from_date, to_date) do
    res = fetch_and_structure_rewards(group_address_hash, from_date, to_date, "group")

    res
    |> then(fn {rewards, total} ->
      %{
        from: from_date,
        rewards: Enum.map(rewards, &Map.delete(&1, :group)),
        to: to_date,
        total_reward_celo: total,
        group: group_address_hash
      }
    end)
  end

  def calculate_multiple_accounts(voter_address_hash_list, from_date, to_date) do
    reward_lists_chunked_by_account =
      voter_address_hash_list
      |> Enum.map(fn hash -> calculate(hash, from_date, to_date) end)

    {rewards, rewards_sum} =
      add_input_account_to_individual_rewards_and_calculate_sum(reward_lists_chunked_by_account, :group)

    %{from: from_date, to: to_date, rewards: rewards, total_reward_celo: rewards_sum}
  end
end
