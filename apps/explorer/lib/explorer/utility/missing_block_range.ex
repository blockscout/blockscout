defmodule Explorer.Utility.MissingBlockRange do
  @moduledoc """
  Module is responsible for keeping the ranges of blocks that need to be (re)fetched.
  """
  use Explorer.Schema

  alias Explorer.Chain.{Block, BlockNumberHelper}
  alias Explorer.Repo

  @default_returning_batch_size 10

  @typedoc """
  * `from_number`: The lower bound of the block range.
  * `to_number`: The upper bound of the block range.
  """
  typed_schema "missing_block_ranges" do
    field(:from_number, :integer)
    field(:to_number, :integer)
    # Currently, the only priority that is used is `1` for contract creation
    # blocks fetch. Whenever we introduce additional priorities, we MUST change
    # this field to `Ecto.Enum`, like this:
    #
    # ```elixir
    # field(:priority, Ecto.Enum, values: [contract_creation: 1, something_else: 2])
    # ```
    #
    # or like this:
    #
    # ```elixir
    # field(:priority, Ecto.Enum, values: [low: 1, medium: 2, high: 3])
    # ```

    field(:priority, :integer)
  end

  @doc false
  def changeset(range \\ %__MODULE__{}, params) do
    cast(range, params, [:from_number, :to_number, :priority])
  end

  @doc """
    Fetches the minimum and maximum block numbers from all missing block ranges.

    Returns a map with:
    - `:min` - The minimum `to_number` across all ranges, or nil if no ranges exist
    - `:max` - The maximum `from_number` across all ranges, or nil if no ranges exist

    This gives the overall bounds of all missing block ranges in the database.
  """
  @spec fetch_min_max() :: %{min: non_neg_integer() | nil, max: non_neg_integer() | nil}
  def fetch_min_max do
    Repo.one(min_max_block_query())
  end

  @doc """
  Retrieves the latest batch of missing block ranges from the database.

  This function queries the database for the latest missing block ranges and processes them
  to return a list of ranges, each represented as a `Range` struct. The size of the batch
  can be customized by providing the `size` argument, or it defaults to `@default_returning_batch_size`.

  ## Parameters

    - `size` (integer, optional): The maximum number of blocks to include in the batch. Defaults to `@default_returning_batch_size`.

  ## Returns

    - A list of `Range` structs, where each range represents a contiguous block range of missing blocks.

  """
  @spec get_latest_batch(integer()) :: [__MODULE__.t()]
  def get_latest_batch(size \\ @default_returning_batch_size) do
    size
    |> get_latest_ranges_query()
    |> Repo.all()
    |> Enum.reduce_while({size, []}, fn %{from_number: from, to_number: to}, {remaining_count, ranges} ->
      range_size = from - to + 1

      cond do
        range_size < remaining_count ->
          {:cont, {remaining_count - range_size, [Range.new(from, to, -1) | ranges]}}

        range_size > remaining_count ->
          {:halt, {0, [Range.new(from, from - remaining_count + 1, -1) | ranges]}}

        range_size == remaining_count ->
          {:halt, {0, [Range.new(from, to, -1) | ranges]}}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  @doc """
  Adds ranges derived from a list of block numbers and saves them with a given priority.

  ## Parameters

    - `numbers`: A list of block numbers to be converted into ranges.
    - `priority`: The priority level to associate with the saved ranges.

  ## Returns

    - The result of the `save_batch/2` function, which processes and persists the ranges.

  This function first converts the list of block numbers into ranges using `numbers_to_ranges/1`
  and then saves the resulting ranges in a batch with the specified priority.
  """
  @spec add_ranges_by_block_numbers([Block.block_number()], integer() | nil) :: [__MODULE__.t()]
  def add_ranges_by_block_numbers(numbers, priority) do
    numbers
    |> numbers_to_ranges()
    |> save_batch(priority)
  end

  # Saves a range of block numbers with an optional priority.

  # This function handles the insertion, deletion, and splitting of block ranges
  # based on the given range and priority. It ensures that overlapping or adjacent
  # ranges are managed correctly, taking into account their priorities.

  # ## Parameters

  #   - `from..to`: A `Range.t()` representing the range of block numbers to save.
  #   - `priority`: An optional integer representing the priority of the range. If
  #     `nil`, the range will not have a priority.

  # ## Returns

  #   - `:ok`: If the operation completes successfully without returning a range.
  #   - `{:ok, t()}`: If the operation completes successfully and returns a range.
  #   - `{:error, Ecto.Changeset.t()}`: If there is an error during the operation.

  # ## Behavior

  # The function performs the following actions based on the existing ranges:

  #   - If both the lower and higher bounds of the range belong to the same existing
  #     range, it updates the priority and splits the range into smaller ranges if
  #     necessary.
  #   - If only one bound of the range overlaps with an existing range, it deletes
  #     the overlapping range if it has a lower priority and fills the gap between
  #     the new range and the existing range.
  #   - If the range overlaps with two different existing ranges, it deletes the
  #     overlapping ranges with lower priority, fills the gap between them, and
  #     adjusts the priorities of the resulting ranges.
  #   - If the range does not overlap with any existing range, it simply fills the
  #     range with the given priority.

  # This function ensures that the block ranges are stored in a consistent and
  # non-overlapping manner, respecting the priority of each range.
  @spec save_range(Range.t(), integer() | nil) :: :ok | {:ok, t()} | {:error, Ecto.Changeset.t()}
  def save_range(from..to//_, priority) do
    min_number = min(from, to)
    max_number = max(from, to)

    lower_range = get_range_by_block_number(min_number)
    higher_range = get_range_by_block_number(max_number)

    case {lower_range, higher_range} do
      {%__MODULE__{} = same_range, %__MODULE__{} = same_range} ->
        if is_nil(same_range.priority) && not is_nil(priority) do
          Repo.delete(same_range)

          inside_range_params = %{from_number: max_number, to_number: min_number, priority: priority}
          insert_range(inside_range_params)

          insert_outside_right_range_params(same_range, min_number)
          insert_outside_left_range_params(same_range, max_number)
        end

      {%__MODULE__{} = range, nil} ->
        delete_less_priority_range(range, priority)
        split_right_range_priorities(range, priority, min_number)
        fill_ranges_between(max_number, range.from_number + 1, priority)

      {nil, %__MODULE__{} = range} ->
        delete_less_priority_range(range, priority)
        split_left_range_priorities(range, priority, max_number)
        fill_ranges_between(range.to_number - 1, min_number, priority)

      {%__MODULE__{} = range_1, %__MODULE__{} = range_2} ->
        delete_less_priority_range(range_2, priority)
        delete_less_priority_range(range_1, priority)

        split_left_range_priorities(range_2, priority, max_number)
        split_right_range_priorities(range_1, priority, min_number)

        fill_ranges_between(range_2.to_number - 1, range_1.from_number + 1, priority)

      {nil, nil} ->
        fill_ranges_between(max_number, min_number, priority)
    end
  end

  @spec insert_inside_left_range_params(__MODULE__.t(), Block.block_number(), integer() | nil) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  defp insert_inside_left_range_params(range, max_number, priority) do
    inside_left_range_params = %{from_number: max_number, to_number: range.to_number, priority: priority}
    insert_range(inside_left_range_params)
  end

  @spec insert_outside_left_range_params(__MODULE__.t(), Block.block_number()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  defp insert_outside_left_range_params(range, max_number) do
    if range.from_number >= max_number + 1 do
      outside_left_range_params = %{
        from_number: range.from_number,
        to_number: max_number + 1,
        priority: range.priority
      }

      insert_range(outside_left_range_params)
    end
  end

  @spec insert_inside_right_range_params(__MODULE__.t(), Block.block_number(), integer() | nil) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  defp insert_inside_right_range_params(range, min_number, priority) do
    inside_right_range_params = %{from_number: range.from_number, to_number: min_number, priority: priority}
    insert_range(inside_right_range_params)
  end

  @spec insert_outside_right_range_params(__MODULE__.t(), Block.block_number()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  defp insert_outside_right_range_params(range, min_number) do
    if min_number - 1 >= range.to_number do
      outside_right_range_params = %{
        from_number: min_number - 1,
        to_number: range.to_number,
        priority: range.priority
      }

      insert_range(outside_right_range_params)
    end
  end

  @spec delete_less_priority_range(__MODULE__.t(), integer() | nil) :: any()
  defp delete_less_priority_range(range, priority) do
    if is_nil(range.priority) && not is_nil(priority) do
      delete_range(range.from_number..range.to_number)
    end
  end

  @spec split_left_range_priorities(__MODULE__.t(), integer() | nil, Block.block_number()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  defp split_left_range_priorities(range, priority, pivot_number) do
    if is_nil(range.priority) && not is_nil(priority) do
      insert_inside_left_range_params(range, pivot_number, priority)
      insert_outside_left_range_params(range, pivot_number)
    end
  end

  @spec split_right_range_priorities(__MODULE__.t(), integer() | nil, Block.block_number()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  defp split_right_range_priorities(range, priority, pivot_number) do
    if is_nil(range.priority) && not is_nil(priority) do
      insert_inside_right_range_params(range, pivot_number, priority)
      insert_outside_right_range_params(range, pivot_number)
    end
  end

  defp delete_range(from..to//_) do
    min_number = min(from, to)
    max_number = max(from, to)

    lower_range = get_range_by_block_number(min_number)
    higher_range = get_range_by_block_number(max_number)

    case {lower_range, higher_range} do
      {%__MODULE__{} = same_range, %__MODULE__{} = same_range} ->
        Repo.delete(same_range)

        if same_range.from_number > max_number do
          insert_range(%{
            from_number: same_range.from_number,
            to_number: BlockNumberHelper.next_block_number(max_number)
          })
        end

        if same_range.to_number < min_number do
          insert_range(%{
            from_number: BlockNumberHelper.previous_block_number(min_number),
            to_number: same_range.to_number
          })
        end

      {%__MODULE__{} = range, nil} ->
        delete_ranges_between(max_number, range.from_number)
        update_from_number_or_delete_range(range, min_number)

      {nil, %__MODULE__{} = range} ->
        delete_ranges_between(range.to_number, min_number)
        update_to_number_or_delete_range(range, max_number)

      {%__MODULE__{} = range_1, %__MODULE__{} = range_2} ->
        delete_ranges_between(range_2.to_number, range_1.from_number)
        update_from_number_or_delete_range(range_1, min_number)
        update_to_number_or_delete_range(range_2, max_number)

      _ ->
        delete_ranges_between(max_number, min_number)
    end
  end

  def clear_batch(batch) do
    Enum.map(batch, &delete_range/1)
  end

  @doc """
    Saves multiple block ranges to the missing blocks tracking system.

    Takes a list of ranges and processes each one through `save_range/1`, handling
    all the necessary merging and overlap cases. The input is wrapped in a list
    to handle both single ranges and lists of ranges.

    ## Parameters
    - `batch`: A single `Range` or list of `Range` structs to save

    ## Returns
    - `:ok` regardless of individual range save results
  """
  @spec save_batch(Range.t() | [Range.t()], integer() | nil) :: [__MODULE__.t()]
  def save_batch(batch, priority \\ nil) do
    batch
    |> List.wrap()
    |> Enum.map(fn batches ->
      save_range(batches, priority)
    end)
  end

  @doc """
    Finds the first range in the table where the set, consisting of numbers from `lower_number` to `higher_number`, intersects.

    ## Parameters
    - `lower_number`: The lower bound of the range to check.
    - `higher_number`: The upper bound of the range to check.

    ## Returns
    - Returns `nil` if no intersecting ranges are found, or an `Explorer.Utility.MissingBlockRange` instance of the first intersecting range otherwise.
  """
  @spec intersects_with_range(Block.block_number(), Block.block_number()) ::
          nil | __MODULE__.t()
  def intersects_with_range(lower_number, higher_number)
      when is_integer(lower_number) and lower_number >= 0 and
             is_integer(higher_number) and lower_number <= higher_number do
    query =
      from(
        r in __MODULE__,
        # Note: from_number is higher than to_number, so in fact the range is to_number..from_number
        # The first case: lower_number..to_number..higher_number
        # The second case: lower_number..from_number..higher_number
        # The third case: to_number..lower_number..higher_number..from_number
        where:
          (^lower_number <= r.to_number and ^higher_number >= r.to_number) or
            (^lower_number <= r.from_number and ^higher_number >= r.from_number) or
            (^lower_number >= r.to_number and ^higher_number <= r.from_number),
        limit: 1
      )

    query
    |> Repo.one()
  end

  # Inserts a new missing block range record with the provided parameters
  @spec insert_range(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  defp insert_range(params) do
    params
    |> changeset()
    |> Repo.insert()
  end

  # Updates a missing block range record with the provided parameters
  @spec update_range(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  defp update_range(range, params) do
    range
    |> changeset(params)
    |> Repo.update()
  end

  defp update_from_number_or_delete_range(%{to_number: to} = range, from) when from <= to, do: Repo.delete(range)
  defp update_from_number_or_delete_range(range, from), do: update_range(range, %{from_number: from})

  defp update_to_number_or_delete_range(%{from_number: from} = range, to) when to >= from, do: Repo.delete(range)
  defp update_to_number_or_delete_range(range, to), do: update_range(range, %{to_number: to})

  @doc """
    Fetches the range of blocks that includes the given block number if it falls
    within any of the ranges that need to be (re)fetched.

    ## Parameters
    - `number`: The block number to check against the missing block ranges.

    ## Returns
    - A single range record of `Explorer.Utility.MissingBlockRange` that includes
      the given block number, or `nil` if no such range is found.
  """
  @spec get_range_by_block_number(Block.block_number(), integer() | nil | :not_specified) :: nil | __MODULE__.t()
  def get_range_by_block_number(number, priority \\ :not_specified) do
    number
    |> include_bound_query()
    |> priority_query(priority)
    |> Repo.one()
  end

  # Fills all missing block ranges that overlap with the interval [from, to]
  @spec fill_ranges_between(Block.block_number(), Block.block_number(), integer() | nil) :: :ok
  defp fill_ranges_between(from, to, priority) when from >= to do
    __MODULE__
    |> where([r], fragment("int4range(?, ?, '[]') @> int4range(?, ?, '[]')", ^to, ^from, r.to_number, r.from_number))
    |> priority_filter(priority)
    |> Repo.delete_all()

    # select all left priority ranges
    priority_ranges = select_all_ranges_within_the_range(from, to)

    if Enum.empty?(priority_ranges) do
      # if no priority ranges inside the requested interval, fill the full range
      insert_or_update_adjacent_ranges(from, to, priority, :both)
    else
      full_range_map_set =
        from
        |> Range.new(to)
        |> Enum.to_list()
        |> MapSet.new()

      priority_ranges
      |> Enum.reduce(full_range_map_set, fn range, acc ->
        map_set =
          range.from_number
          |> Range.new(range.to_number)
          |> Enum.to_list()
          |> MapSet.new()

        acc
        |> MapSet.difference(map_set)
      end)
      |> MapSet.to_list()
      |> Enum.sort_by(& &1, :desc)
      |> Enum.reduce({[], {nil, nil}}, fn num, {ranges, {start_range, end_range}} ->
        if is_nil(start_range) do
          {ranges, {num, num}}
        else
          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if end_range - num > 1 do
            {[Range.new(start_range, end_range) | ranges], {num, num}}
          else
            {ranges, {start_range, num}}
          end
        end
      end)
      |> then(fn {ranges, {start_range, end_range}} ->
        if not is_nil(start_range) && not is_nil(end_range) do
          [Range.new(start_range, end_range) | ranges]
        else
          ranges
        end
      end)
      |> then(fn
        [range | []] ->
          insert_or_update_adjacent_ranges(range.first, range.last, priority, :both)

        [lowest_range | rest_ranges] ->
          [highest_range | middle_ranges] = Enum.reverse(rest_ranges)

          insert_or_update_adjacent_ranges(lowest_range.first, lowest_range.last, priority, :down)
          insert_or_update_adjacent_ranges(highest_range.first, highest_range.last, priority, :up)

          middle_ranges
          |> Enum.each(fn %Range{first: first, last: last} ->
            range_params = %{from_number: first, to_number: last, priority: priority}
            insert_range(range_params)
          end)

        [] ->
          :ok
      end)
    end

    :ok
  end

  defp fill_ranges_between(_from, _to, _priority), do: :ok

  defp insert_or_update_adjacent_ranges(from, to, priority, :both) do
    upper_range = get_range_by_block_number(from + 1, priority)
    lower_range = get_range_by_block_number(to - 1, priority)

    case {lower_range, upper_range} do
      {nil, nil} ->
        insert_range(%{from_number: from, to_number: to, priority: priority})

      {_, nil} ->
        update_range(lower_range, %{from_number: from})

      {nil, _} ->
        update_range(upper_range, %{to_number: to})

      {_, _} ->
        Repo.delete(lower_range)
        update_range(upper_range, %{to_number: lower_range.to_number})
    end
  end

  defp insert_or_update_adjacent_ranges(from, to, priority, direction) do
    {range, update_params} =
      case direction do
        :up -> {get_range_by_block_number(from + 1, priority), %{to_number: to}}
        :down -> {get_range_by_block_number(to - 1, priority), %{from_number: from}}
      end

    if is_nil(range) do
      insert_range(%{from_number: from, to_number: to, priority: priority})
    else
      update_range(range, update_params)
    end
  end

  defp select_all_ranges_within_the_range(from, to) do
    __MODULE__
    |> where([r], fragment("int4range(?, ?, '[]') @> int4range(?, ?, '[]')", ^to, ^from, r.to_number, r.from_number))
    |> order_by([r], desc: r.from_number)
    |> Repo.all()
  end

  defp priority_filter(query, nil) do
    where(query, [r], is_nil(r.priority))
  end

  defp priority_filter(query, _priority) do
    query
  end

  # Deletes all missing block ranges that overlap with the interval [from, to]
  @spec delete_ranges_between(Block.block_number(), Block.block_number()) :: :ok
  defp delete_ranges_between(from, to) do
    __MODULE__
    |> where([r], fragment("int4range(?, ?, '()') @> int4range(?, ?, '[]')", ^to, ^from, r.to_number, r.from_number))
    |> Repo.delete_all()
  end

  def sanitize_missing_block_ranges do
    __MODULE__
    |> where([r], r.from_number < r.to_number)
    |> update([r], set: [from_number: r.to_number, to_number: r.from_number])
    |> Repo.update_all([], timeout: :infinity)

    {last_range, merged_ranges} = delete_and_merge_ranges()

    save_batch((last_range && [last_range | merged_ranges]) || [])
  end

  defp delete_and_merge_ranges do
    delete_intersecting_ranges()
    |> Enum.sort_by(& &1.from_number, &>=/2)
    |> Enum.reduce({nil, []}, fn %{from_number: from, to_number: to}, {last_range, result} ->
      cond do
        is_nil(last_range) -> {from..to, result}
        Range.disjoint?(from..to, last_range) -> {from..to, [last_range | result]}
        true -> {Range.new(max(from, last_range.first), min(to, last_range.last)), result}
      end
    end)
  end

  defp delete_intersecting_ranges do
    {_, intersecting_ranges} =
      __MODULE__
      |> join(:inner, [r], r1 in __MODULE__,
        on:
          ((r1.from_number <= r.from_number and r1.from_number >= r.to_number) or
             (r1.to_number <= r.from_number and r1.to_number >= r.to_number) or
             (r.from_number <= r1.from_number and r.from_number >= r1.to_number) or
             (r.to_number <= r1.from_number and r.to_number >= r1.to_number)) and r1.id != r.id
      )
      |> select([r, r1], r)
      |> Repo.delete_all(timeout: :infinity)

    intersecting_ranges
  end

  @doc """
    Returns a query to fetch the minimum and maximum block numbers from all missing block ranges.

    The query returns a map with:
    - `:min` - The minimum `to_number` across all ranges
    - `:max` - The maximum `from_number` across all ranges

    This gives the overall bounds of all missing block ranges in the database.
  """
  @spec min_max_block_query() :: Ecto.Query.t()
  def min_max_block_query do
    from(r in __MODULE__, select: %{min: min(r.to_number), max: max(r.from_number)})
  end

  defp get_latest_ranges_query(size) do
    from(r in __MODULE__, order_by: [desc_nulls_last: r.priority, desc: r.from_number], limit: ^size)
  end

  @doc """
    Filters missing block ranges to those starting below a specified block number.

    Builds a query that finds ranges where the `from_number` field is less than
    the provided lower bound. Can be chained with other query conditions.

    ## Parameters
    - `query`: Optional base query to extend. Defaults to the `MissingBlockRange` schema
    - `lower_bound`: Block number that the range's `from_number` must be below

    ## Returns
    An `Ecto.Query` that can be further refined or executed
  """
  @spec from_number_below_query(Ecto.Query.t() | __MODULE__, Block.block_number()) :: Ecto.Query.t()
  def from_number_below_query(query \\ __MODULE__, lower_bound) do
    from(r in query, where: r.from_number < ^lower_bound)
  end

  @doc """
    Filters missing block ranges to those extending above a specified block number.

    Builds a query that finds ranges where the `to_number` field is greater than
    the provided upper bound. Can be chained with other query conditions.

    ## Parameters
    - `query`: Optional base query to extend. Defaults to the `MissingBlockRange` schema
    - `upper_bound`: Block number that the range's `to_number` must exceed

    ## Returns
    An `Ecto.Query` that can be further refined or executed
  """
  @spec to_number_above_query(Ecto.Query.t() | __MODULE__, Block.block_number()) :: Ecto.Query.t()
  def to_number_above_query(query \\ __MODULE__, upper_bound) do
    from(r in query, where: r.to_number > ^upper_bound)
  end

  @doc """
    Constructs a query to check if a given block number falls within any of the
    ranges of blocks that need to be (re)fetched.

    ## Parameters
    - `bound`: The block number to check against the missing block ranges.

    ## Returns
    - A query that can be used to find ranges where the given block number is
      within the `from_number` and `to_number` bounds.
  """
  @spec include_bound_query(Block.block_number()) :: Ecto.Query.t()
  def include_bound_query(bound) do
    from(r in __MODULE__, where: fragment("int4range(?, ?, '[]') @> ?::int", r.to_number, r.from_number, ^bound))
  end

  defp priority_query(query, :not_specified), do: query
  defp priority_query(query, nil), do: where(query, [m], is_nil(m.priority))
  defp priority_query(query, _priority), do: where(query, [m], not is_nil(m.priority))

  defp numbers_to_ranges([]), do: []

  defp numbers_to_ranges(numbers) when is_list(numbers) do
    numbers
    |> Enum.sort()
    |> Enum.chunk_while(
      nil,
      fn
        number, nil ->
          {:cont, number..number}

        number, first..last//_ when number == last + 1 ->
          {:cont, first..number}

        number, range ->
          {:cont, range, number..number}
      end,
      fn range -> {:cont, range, nil} end
    )
  end
end
