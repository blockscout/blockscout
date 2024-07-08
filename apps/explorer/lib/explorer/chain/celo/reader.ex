defmodule Explorer.Chain.Celo.Reader do
  @moduledoc "Read functions for Celo modules"

  import Ecto.Query, only: [limit: 2]

  import Explorer.Chain,
    only: [
      select_repo: 1,
      join_associations: 2,
      default_paging_options: 0
    ]

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.Celo.ElectionReward

  alias Explorer.Chain.{Hash, Token, Wei}

  @election_reward_types ElectionReward.types()
  @default_paging_options default_paging_options()

  def address_hash_to_election_rewards(address_hash, options \\ []) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    address_hash
    |> ElectionReward.address_hash_to_rewards_query()
    |> ElectionReward.paginate(paging_options)
    |> limit(^paging_options.page_size)
    |> join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  @spec block_hash_to_election_rewards_by_type(
          Hash.t(),
          ElectionReward.type()
        ) :: [
          ElectionReward.t()
        ]
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

  @spec block_hash_to_aggregated_election_rewards_by_type(Hash.Full.t()) ::
          %{atom() => Wei.t() | nil}
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

    # Return a map with all possible election reward types, even if they are not
    # present in the database.
    ElectionReward.types()
    |> Map.new(&{&1, %{total: Decimal.new(0), count: 0}})
    |> Map.merge(reward_type_to_aggregated_rewards)
    |> Map.new(fn {type, aggregated_reward} ->
      token = Map.get(reward_type_to_token, type)
      aggregated_reward_with_token = Map.put(aggregated_reward, :token, token)
      {type, aggregated_reward_with_token}
    end)
  end

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
end
