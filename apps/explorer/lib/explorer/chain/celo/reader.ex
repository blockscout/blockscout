defmodule Explorer.Chain.Celo.Reader do
  @moduledoc "Read functions for Celo modules"

  import Ecto.Query, only: [limit: 2]

  import Explorer.Chain,
    only: [
      select_repo: 1,
      join_associations: 2,
      default_paging_options: 0
    ]

  alias Explorer.Chain.Celo.ElectionReward
  alias Explorer.Chain.{Hash, Wei}

  @election_reward_types ElectionReward.types()

  @spec block_hash_to_election_rewards_by_type(
          Hash.t(),
          ElectionReward.type()
        ) :: [
          ElectionReward.t()
        ]
  def block_hash_to_election_rewards_by_type(block_hash, reward_type, options \\ [])
      when reward_type in @election_reward_types do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

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
    block_hash
    |> ElectionReward.block_hash_to_aggregated_rewards_by_type_query()
    |> select_repo(options).all()
    |> Map.new()
  end
end
