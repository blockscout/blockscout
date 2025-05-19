defmodule Explorer.Chain.Block.Reader.General do
  @moduledoc """
  Provides general methods for reading block data from the database.
  """

  import Ecto.Query,
    only: [
      from: 2,
      subquery: 1,
      union: 2
    ]

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Repo

  alias Explorer.Chain.{
    Block,
    BlockNumberHelper
  }

  require Logger

  @doc """
    Converts a timestamp to its nearest block number.

    Locates the block number closest to a given timestamp, with options to adjust the
    search to find blocks either before or after the timestamp, and to handle null
    rounds in the blockchain.

    ## Parameters
    - `given_timestamp`: The timestamp for which the closest block number is
      being sought.
    - `closest`: A direction indicator (`:before` or `:after`) specifying
                whether the block number returned should be before or after the
                given timestamp.
    - `from_api`: A boolean flag indicating whether to use the replica database
                  or the primary one for the query.
    - `strict`: A boolean flag controlling the block selection behavior:
      * `false` (default): Returns the block with smallest absolute time
        difference, then adjusts based on `closest` parameter if needed. In this
        mode, the function could return a block number which does not exist
        in the database.
      * `true`: Returns strictly the first existing block before/after the
        timestamp based on the `closest` parameter.

    ## Returns
    - `{:ok, block_number}` where `block_number` is the block number closest to
      the specified timestamp.
    - `{:error, :not_found}` if no block is found within the specified criteria
      or if the found block represents a null round.
  """
  @spec timestamp_to_block_number(DateTime.t(), :before | :after, boolean(), boolean()) ::
          {:ok, Block.block_number()} | {:error, :not_found}
  def timestamp_to_block_number(given_timestamp, closest, from_api, strict \\ false)

  def timestamp_to_block_number(given_timestamp, closest, from_api, true) do
    query = build_directional_query(given_timestamp, closest)

    # No need to handle null rounds here as in the strict mode only blocks
    # indexed by the block fetcher are considered. Null rounds are time slots
    # where no Filecoin miner produced a block at all.
    case select_repo(api?: from_api).one(query, timeout: :infinity) do
      nil -> {:error, :not_found}
      %{number: number} -> {:ok, number}
    end
  end

  def timestamp_to_block_number(given_timestamp, closest, from_api, false) do
    # Finds the first block with timestamp less than or equal to the given timestamp
    lt_timestamp_query = build_directional_query(given_timestamp, :before)
    # Finds the first block with timestamp greater than or equal to the given timestamp
    gt_timestamp_query = build_directional_query(given_timestamp, :after)

    # Combines the queries for blocks before and after the timestamp into a single union query
    union_query = lt_timestamp_query |> subquery() |> union(^gt_timestamp_query)

    # Orders blocks by their absolute time difference from the target timestamp,
    # selecting the single closest block regardless of whether it's before or after
    query =
      from(
        block in subquery(union_query),
        select: block,
        order_by: fragment("abs(extract(epoch from (? - ?)))", block.timestamp, ^given_timestamp),
        limit: 1
      )

    case select_repo(api?: from_api).one(query, timeout: :infinity) do
      nil ->
        {:error, :not_found}

      %{number: number, timestamp: timestamp} ->
        block_number = get_block_number_based_on_closest(closest, timestamp, given_timestamp, number)
        {:ok, block_number}
    end
  end

  @doc """
    Fetches timestamps by the given block numbers from the `blocks` database table and returns
    a `block_number -> timestamp` map. The number of keys in resulting map can be less than the
    number of the given block numbers.

    ## Parameters
    - `block_numbers`: The list of block numbers.

    ## Returns
    - The resulting `block_number -> timestamp` map. Can be empty map (%{}).
  """
  @spec timestamps_by_block_numbers([non_neg_integer()]) :: map()
  def timestamps_by_block_numbers([]), do: %{}

  def timestamps_by_block_numbers(block_numbers) when is_list(block_numbers) do
    query =
      from(
        block in Block,
        where: block.number in ^block_numbers and block.consensus == true,
        select: {block.number, block.timestamp}
      )

    query
    |> Repo.all()
    |> Enum.into(%{})
  end

  # Builds a query to find consensus blocks either before or after a given timestamp
  #
  # ## Parameters
  # - `timestamp`: The timestamp to compare against
  # - `direction`: Either `:before` or `:after` to indicate search direction
  #
  # ## Returns
  # - A query that will find the closest consensus block in the specified direction
  @spec build_directional_query(DateTime.t(), :before | :after) :: Ecto.Query.t()
  defp build_directional_query(timestamp, direction) do
    base_query =
      from(block in Block,
        where: block.consensus == true,
        limit: 1
      )

    base_query
    |> case do
      query when direction == :before -> adjust_query_to_highest_block(query, timestamp)
      query when direction == :after -> adjust_query_to_lowest_block(query, timestamp)
    end
  end

  # Adjusts the query to find the highest block number with timestamp <= given timestamp
  #
  # ## Parameters
  # - `query`: The base query to build upon
  # - `timestamp`: The timestamp to compare against
  #
  # ## Returns
  # - A query that will find the highest block before or at the given timestamp.
  #   If multiple blocks have the same timestamp, returns the one with the highest number.
  @spec adjust_query_to_highest_block(Ecto.Query.t(), DateTime.t()) :: Ecto.Query.t()
  defp adjust_query_to_highest_block(query, timestamp) do
    from(block in query,
      where: block.timestamp <= ^timestamp,
      order_by: [desc: block.timestamp, desc: block.number]
    )
  end

  # Adjusts the query to find the lowest block number with timestamp >= given timestamp
  #
  # ## Parameters
  # - `query`: The base query to build upon
  # - `timestamp`: The timestamp to compare against
  #
  # ## Returns
  # - A query that will find the lowest block after or at the given timestamp.
  #   If multiple blocks have the same timestamp, returns the one with the lowest number.
  @spec adjust_query_to_lowest_block(Ecto.Query.t(), DateTime.t()) :: Ecto.Query.t()
  defp adjust_query_to_lowest_block(query, timestamp) do
    from(block in query,
      where: block.timestamp >= ^timestamp,
      order_by: [asc: block.timestamp, asc: block.number]
    )
  end

  # Determines the appropriate block number based on the requested direction and timestamp comparison.
  #
  # Analyzes the relationship between block timestamp and target timestamp to return
  # either the current block number or an adjacent block number, depending on the
  # specified direction (:before or :after) and timestamp comparison result.
  #
  # ## Parameters
  # - `closest`: Either `:before` or `:after` to indicate desired block position
  # - `timestamp`: The timestamp of the current block
  # - `given_timestamp`: The target timestamp for comparison
  # - `number`: The current block number
  #
  # ## Returns
  # - For `:before`: Returns current block number if block timestamp <= given timestamp,
  #   otherwise returns previous block number
  # - For `:after`: Returns current block number if block timestamp >= given timestamp,
  #   otherwise returns next block number
  @spec get_block_number_based_on_closest(:before | :after, DateTime.t(), DateTime.t(), Block.block_number()) ::
          Block.block_number()
  defp get_block_number_based_on_closest(closest, timestamp, given_timestamp, number) do
    # Note: When calculating adjacent block numbers (previous/next) for both `:before`
    # and `:after` cases, there is no guarantee that the calculated block number
    # exists in the database

    case closest do
      :before ->
        if DateTime.compare(timestamp, given_timestamp) in ~w(lt eq)a do
          number
        else
          BlockNumberHelper.previous_block_number(number)
        end

      :after ->
        if DateTime.compare(timestamp, given_timestamp) in ~w(gt eq)a do
          number
        else
          BlockNumberHelper.next_block_number(number)
        end
    end
  end

  @doc """
  Filters the `base_query` to include only the records where the `block_number` falls within the specified period.

  ## Parameters

    - `base_query`: The initial query to be filtered.
    - `from_block`: The starting block number of the period. Can be `nil`.
    - `to_block`: The ending block number of the period. Can be `nil`.

  ## Returns

    - A query filtered by the specified block number period.

  ## Examples

    - When `from_block` is `nil` and `to_block` is not `nil`:
      ```elixir
      where_block_number_in_period(query, nil, 100)
      # Filters the query to include records with block_number <= 100
      ```

    - When `from_block` is not `nil` and `to_block` is `nil`:
      ```elixir
      where_block_number_in_period(query, 50, nil)
      # Filters the query to include records with block_number >= 50
      ```

    - When both `from_block` and `to_block` are `nil`:
      ```elixir
      where_block_number_in_period(query, nil, nil)
      # Returns the base query without any filtering
      ```

    - When both `from_block` and `to_block` are not `nil`:
      ```elixir
      where_block_number_in_period(query, 50, 100)
      # Filters the query to include records with block_number between 50 and 100 (inclusive)
      ```
  """
  @spec where_block_number_in_period(Ecto.Query.t(), non_neg_integer() | nil, non_neg_integer() | nil) :: Ecto.Query.t()
  def where_block_number_in_period(base_query, from_block, to_block) when is_nil(from_block) and not is_nil(to_block) do
    from(q in base_query,
      where: q.block_number <= ^to_block
    )
  end

  def where_block_number_in_period(base_query, from_block, to_block) when not is_nil(from_block) and is_nil(to_block) do
    from(q in base_query,
      where: q.block_number >= ^from_block
    )
  end

  def where_block_number_in_period(base_query, from_block, to_block) when is_nil(from_block) and is_nil(to_block) do
    base_query
  end

  def where_block_number_in_period(base_query, from_block, to_block) do
    from(q in base_query,
      where: q.block_number >= ^from_block and q.block_number <= ^to_block
    )
  end
end
