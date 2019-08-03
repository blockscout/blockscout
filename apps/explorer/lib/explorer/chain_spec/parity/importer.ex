defmodule Explorer.ChainSpec.Parity.Importer do
  @moduledoc """
  Imports data from parity chain spec.
  """

  @max_block_number 9_999_999_999_999_999_999

  def emission_rewards(chain_spec) do
    rewards = chain_spec["engine"]["Ethash"]["params"]["blockReward"]

    rewards
    |> parse_hex_numbers()
    |> format_ranges()
  end

  defp format_ranges(block_number_reward_pairs) do
    block_number_reward_pairs
    |> Enum.chunk_every(2, 1)
    |> Enum.map(fn values ->
      create_range(values)
    end)
  end

  defp create_range([{block_number1, reward}, {block_number2, _}]) do
    %{
      block_range: block_number1..block_number2,
      reward: reward
    }
  end

  defp create_range([{block_number, reward}]) do
    %{
      block_range: block_number..@max_block_number,
      reward: reward
    }
  end

  defp parse_hex_numbers(rewards) do
    Enum.map(rewards, fn {hex_block_number, hex_reward} ->
      block_number = parse_hex_number(hex_block_number)
      reward = parse_hex_number(hex_reward)

      {block_number, reward}
    end)
  end

  defp parse_hex_number("0x" <> hex_number) do
    {number, ""} = Integer.parse(hex_number, 16)

    number
  end
end
