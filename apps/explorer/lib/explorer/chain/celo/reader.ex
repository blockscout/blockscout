defmodule Explorer.Chain.Celo.Reader do
  @moduledoc """
  Read functions for Celo modules.
  """

  alias Explorer.Chain

  alias Explorer.Chain.Block
  alias Explorer.Chain.Cache.Blocks
  alias Explorer.Chain.Celo.Helper

  @doc """
  Retrieves aggregated election rewards by block hash.

  ## Parameters
  - `block_hash` (`Hash.Full.t()`): The block hash to aggregate election
    rewards.
  - `options` (`Keyword.t()`): Optional parameters for fetching data.

  ## Returns
  - `%{atom() => Wei.t() | nil}`: A map of aggregated election rewards by type.

  ## Examples

      iex> block_hash = %Hash.Full{
      ...>   byte_count: 32,
      ...>   bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b :: big-integer-size(32)-unit(8)>>
      ...> }
      iex> Explorer.Chain.Celo.Reader.block_hash_to_aggregated_election_rewards_by_type(block_hash)
      %{voter_reward: %{total: %Decimal{}, count: 2}, ...}
  """
  def foo, do: :ok
  # @spec epoch_number_to_aggregated_election_rewards_by_type(
  #         Hash.Full.t(),
  #         Keyword.t()
  #       ) :: %{atom() => Wei.t() | nil}
  # def epoch_number_to_aggregated_election_rewards_by_type(epoch_number, options \\ []) do
  #   reward_type_to_token =
  #     election_reward_tokens_by_type(options)

  #   reward_type_to_aggregated_rewards =
  #     block_hash
  #     |> ElectionReward.block_hash_to_aggregated_rewards_by_type_query()
  #     |> Chain.select_repo(options).all()
  #     |> Map.new(fn {type, total, count} ->
  #       {type, %{total: total, count: count}}
  #     end)

  #   ElectionReward.types()
  #   |> Map.new(&{&1, %{total: Decimal.new(0), count: 0}})
  #   |> Map.merge(reward_type_to_aggregated_rewards)
  #   |> Map.new(fn {type, aggregated_reward} ->
  #     token = Map.get(reward_type_to_token, type)
  #     aggregated_reward_with_token = Map.put(aggregated_reward, :token, token)
  #     {type, aggregated_reward_with_token}
  #   end)
  # end

  @doc """
  Retrieves the epoch number of the last fetched block.
  """
  @spec last_block_epoch_number(Keyword.t()) :: Block.block_number() | nil
  def last_block_epoch_number(options \\ []) do
    block_number =
      1
      |> Blocks.atomic_take_enough()
      |> case do
        [%Block{number: number}] -> {:ok, number}
        nil -> Chain.max_consensus_block_number(options)
      end
      |> case do
        {:ok, number} -> number
        _ -> nil
      end

    block_number && Helper.block_number_to_epoch_number(block_number)
  end
end
