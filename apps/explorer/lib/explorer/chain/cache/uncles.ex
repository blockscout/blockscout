defmodule Explorer.Chain.Cache.Uncles do
  @moduledoc """
  Caches the last known uncles
  """

  alias Explorer.Chain.Block
  alias Explorer.Repo

  use Explorer.Chain.OrderedCache,
    name: :uncles,
    max_size: 60,
    ids_list_key: "uncle_numbers",
    preload: :transactions,
    preload: [miner: :names],
    preload: :rewards,
    preload: :nephews,
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  import Ecto.Query

  @type element :: Block.t()

  @type id :: non_neg_integer()

  def element_to_id(%Block{number: number}), do: number

  def update_from_second_degree_relations(second_degree_relations) when is_nil(second_degree_relations), do: :ok

  def update_from_second_degree_relations(second_degree_relations) do
    uncle_hashes =
      second_degree_relations
      |> Enum.map(& &1.uncle_hash)
      |> Enum.uniq()

    query =
      from(
        block in Block,
        where: block.consensus == false and block.hash in ^uncle_hashes,
        inner_join: nephews in assoc(block, :nephews),
        preload: [nephews: block]
      )

    query
    |> Repo.all()
    |> update()
  end
end
