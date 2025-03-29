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
  Fetches the minimum and maximum block range from the database.

  This function executes a query to retrieve a single result containing
  the minimum and maximum block values. It uses the `min_max_block_query/0`
  function to construct the query and `Repo.one/1` to execute it.

  ## Returns

  - A map `%{min: min_block, max: max_block}` representing the minimum and maximum
    block values, or `nil` if no blocks are found in the database.
  """
  @spec fetch_min_max() :: map() | nil
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

  defp save_range(from..to//_, priority) when not is_nil(priority) do
    min_number = min(from, to)
    max_number = max(from, to)

    delete_ranges_between(max_number, min_number)
    insert_range(%{from_number: max_number, to_number: min_number, priority: priority})
  end

  defp save_range(from..to//_, nil) do
    min_number = min(from, to)
    max_number = max(from, to)

    lower_range = get_range_by_block_number(min_number)
    higher_range = get_range_by_block_number(max_number)

    case {lower_range, higher_range} do
      {%__MODULE__{} = same_range, %__MODULE__{} = same_range} ->
        :ok

      {%__MODULE__{} = range, nil} ->
        delete_ranges_between(max_number, range.from_number)
        update_range(range, %{from_number: max_number})

      {nil, %__MODULE__{} = range} ->
        delete_ranges_between(range.to_number, min_number)
        update_range(range, %{to_number: min_number})

      {%__MODULE__{} = range_1, %__MODULE__{} = range_2} ->
        delete_ranges_between(range_2.from_number + 1, range_1.from_number)
        update_range(range_1, %{from_number: range_2.from_number})

      _ ->
        delete_ranges_between(max_number, min_number)
        insert_range(%{from_number: max_number, to_number: min_number})
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
  Saves a batch of missing block ranges with an optional priority.

  ## Parameters

    - `batch` (list or single element): A batch or a single missing block range to be saved.
      If a single element is provided, it will be wrapped in a list.
    - `priority` (any, optional): An optional priority value to associate with the batch.
      Defaults to `nil`.

  ## Returns

    - A list of results from saving each range in the batch.
  """
  @spec save_batch([Block.block_number()], integer() | nil) :: [__MODULE__.t()]
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

  defp insert_range(params) do
    params
    |> changeset()
    |> Repo.insert()
  end

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
  @spec get_range_by_block_number(Block.block_number()) :: nil | __MODULE__.t()
  def get_range_by_block_number(number) do
    number
    |> include_bound_query()
    |> Repo.one()
  end

  defp delete_ranges_between(from, to) do
    from
    |> from_number_below_query()
    |> to_number_above_query(to)
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

  defp min_max_block_query do
    from(r in __MODULE__, select: %{min: min(r.to_number), max: max(r.from_number)})
  end

  defp get_latest_ranges_query(size) do
    from(r in __MODULE__, order_by: [desc_nulls_last: r.priority, desc: r.from_number], limit: ^size)
  end

  def from_number_below_query(query \\ __MODULE__, lower_bound) do
    from(r in query, where: r.from_number < ^lower_bound)
  end

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
    from(r in __MODULE__, where: r.from_number >= ^bound, where: r.to_number <= ^bound)
  end

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
