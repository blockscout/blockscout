defmodule Explorer.Chain.Celo.Reader do
  @moduledoc """
  Read functions for Celo modules.
  """

  import Ecto.Query, only: [limit: 2]

  import Explorer.Chain,
    only: [
      select_repo: 1,
      join_associations: 2,
      default_paging_options: 0,
      max_consensus_block_number: 1
    ]

  alias Explorer.Chain.Block
  alias Explorer.Chain.Cache.{Blocks, CeloCoreContracts}
  alias Explorer.Chain.Celo.{ElectionReward, Helper}
  alias Explorer.Chain.{Hash, Token, Wei}

  @election_reward_types ElectionReward.types()
  @default_paging_options default_paging_options()

  @doc """
  Retrieves election rewards associated with a given address hash.

  ## Parameters
  - `address_hash` (`Hash.Address.t()`): The address hash to search for election
    rewards.
  - `options` (`Keyword.t()`): Optional parameters for fetching data.

  ## Returns
  - `[ElectionReward.t()]`: A list of election rewards associated with the
    address hash.

  ## Examples

      iex> address_hash = %Hash.Address{
      ...>   byte_count: 20,
      ...>   bytes: <<0x1d1f7f0e1441c37e28b89e0b5e1edbbd34d77649 :: size(160)>>
      ...> }
      iex> Explorer.Chain.Celo.Reader.address_hash_to_election_rewards(address_hash)
      [%ElectionReward{}, ...]
  """
  @spec address_hash_to_election_rewards(
          Hash.Address.t(),
          Keyword.t()
        ) :: [ElectionReward.t()]
  def address_hash_to_election_rewards(address_hash, options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    address_hash
    |> ElectionReward.address_hash_to_ordered_rewards_query()
    |> ElectionReward.join_token()
    |> ElectionReward.paginate(paging_options)
    |> limit(^paging_options.page_size)
    |> join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  @doc """
  Retrieves election rewards by block hash and reward type.

  ## Parameters
  - `block_hash` (`Hash.t()`): The block hash to search for election rewards.
  - `reward_type` (`ElectionReward.type()`): The type of reward to filter.
  - `options` (`Keyword.t()`): Optional parameters for fetching data.

  ## Returns
  - `[ElectionReward.t()]`: A list of election rewards filtered by block hash
    and reward type.

  ## Examples

      iex> block_hash = %Hash.Full{
      ...>   byte_count: 32,
      ...>   bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b :: big-integer-size(32)-unit(8)>>
      ...> }
      iex> Explorer.Chain.Celo.Reader.block_hash_to_election_rewards_by_type(block_hash, :voter_reward)
      [%ElectionReward{}, ...]
  """
  @spec block_hash_to_election_rewards_by_type(
          Hash.t(),
          ElectionReward.type(),
          Keyword.t()
        ) :: [ElectionReward.t()]
  def block_hash_to_election_rewards_by_type(block_hash, reward_type, options \\ [])
      when reward_type in @election_reward_types do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    block_hash
    |> ElectionReward.block_hash_to_rewards_by_type_query(reward_type)
    |> ElectionReward.paginate(paging_options)
    |> limit(^paging_options.page_size)
    |> join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

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
  @spec block_hash_to_aggregated_election_rewards_by_type(
          Hash.Full.t(),
          Keyword.t()
        ) :: %{atom() => Wei.t() | nil}
  def block_hash_to_aggregated_election_rewards_by_type(block_hash, options \\ []) do
    reward_type_to_token =
      block_hash_to_election_reward_token_addresses_by_type(
        block_hash,
        options
      )

    reward_type_to_aggregated_rewards =
      block_hash
      |> ElectionReward.block_hash_to_aggregated_rewards_by_type_query()
      |> select_repo(options).all()
      |> Map.new(fn {type, total, count} ->
        {type, %{total: total, count: count}}
      end)

    ElectionReward.types()
    |> Map.new(&{&1, %{total: Decimal.new(0), count: 0}})
    |> Map.merge(reward_type_to_aggregated_rewards)
    |> Map.new(fn {type, aggregated_reward} ->
      token = Map.get(reward_type_to_token, type)
      aggregated_reward_with_token = Map.put(aggregated_reward, :token, token)
      {type, aggregated_reward_with_token}
    end)
  end

  # Retrieves the token for each type of election reward on the given block.
  #
  # ## Parameters
  # - `block_hash` (`Hash.Full.t()`): The block hash to search for token
  #   addresses.
  # - `options` (`Keyword.t()`): Optional parameters for fetching data.
  #
  # ## Returns
  # - `%{atom() => Token.t() | nil}`: A map of reward types to token.
  #
  # ## Examples
  #
  #     iex> block_hash = %Hash.Full{
  #     ...>   byte_count: 32,
  #     ...>   bytes: <<0x9fc76417374aa880d4449a1f7f31ec597f00b1f6f3dd2d66f4c9c6c445836d8b :: big-integer-size(32)-unit(8)>>
  #     ...> }
  #     iex> Explorer.Chain.Celo.Reader.block_hash_to_election_reward_token_addresses_by_type(block_hash)
  #     %{voter_reward: %Token{}, ...}
  @spec block_hash_to_election_reward_token_addresses_by_type(
          Hash.Full.t(),
          Keyword.t()
        ) :: %{atom() => Token.t() | nil}
  defp block_hash_to_election_reward_token_addresses_by_type(block_hash, options) do
    contract_address_hash_to_atom =
      ElectionReward.reward_type_atom_to_token_atom()
      |> Map.values()
      |> Map.new(fn token_atom ->
        {:ok, contract_address_hash} = CeloCoreContracts.get_address(token_atom, block_hash)
        {contract_address_hash, token_atom}
      end)

    token_atom_to_token =
      contract_address_hash_to_atom
      |> Map.keys()
      |> Token.get_by_contract_address_hashes(options)
      |> Map.new(fn token ->
        hash = to_string(token.contract_address_hash)
        atom = contract_address_hash_to_atom[hash]
        {atom, token}
      end)

    ElectionReward.reward_type_atom_to_token_atom()
    |> Map.new(fn {reward_type_atom, token_atom} ->
      {reward_type_atom, Map.get(token_atom_to_token, token_atom)}
    end)
  end

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
        nil -> max_consensus_block_number(options)
      end
      |> case do
        {:ok, number} -> number
        _ -> nil
      end

    block_number && Helper.block_number_to_epoch_number(block_number)
  end
end
