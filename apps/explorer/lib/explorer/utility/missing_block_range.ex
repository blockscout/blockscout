defmodule Explorer.Utility.MissingBlockRange do
  @moduledoc """
  Module is responsible for keeping the ranges of blocks that need to be (re)fetched.
  """
  use Explorer.Schema

  alias Explorer.Repo

  @default_returning_batch_size 10

  schema "missing_block_ranges" do
    field(:from_number, :integer)
    field(:to_number, :integer)
  end

  @doc false
  def changeset(range \\ %__MODULE__{}, params) do
    cast(range, params, [:from_number, :to_number])
  end

  def fetch_min_max do
    Repo.one(min_max_block_query())
  end

  def get_latest_batch(size \\ @default_returning_batch_size) do
    size
    |> get_latest_ranges_query()
    |> Repo.all()
    |> Enum.map(fn %{from_number: from, to_number: to} ->
      %Range{first: from, last: to, step: if(from > to, do: -1, else: 1)}
    end)
  end

  def add_ranges_by_block_numbers(numbers) do
    numbers
    |> numbers_to_ranges()
    |> save_batch()
  end

  def save_range(from..to) do
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
        delete_ranges_between(range_2.from_number, range_1.from_number)
        update_range(range_1, %{from_number: range_2.from_number})

      _ ->
        insert_range(%{from_number: max_number, to_number: min_number})
    end
  end

  def delete_range(from..to) do
    min_number = min(from, to)
    max_number = max(from, to)

    lower_range = get_range_by_block_number(min_number)
    higher_range = get_range_by_block_number(max_number)

    case {lower_range, higher_range} do
      {%__MODULE__{} = same_range, %__MODULE__{} = same_range} ->
        Repo.delete(same_range)
        insert_if_needed(%{from_number: same_range.from_number, to_number: max_number + 1})
        insert_if_needed(%{from_number: min_number - 1, to_number: same_range.to_number})

      {%__MODULE__{} = range, nil} ->
        delete_ranges_between(max_number, range.from_number)
        update_from_number_or_delete_range(range, min_number - 1)

      {nil, %__MODULE__{} = range} ->
        delete_ranges_between(range.to_number, min_number)
        update_to_number_or_delete_range(range, max_number + 1)

      {%__MODULE__{} = range_1, %__MODULE__{} = range_2} ->
        delete_ranges_between(range_2.to_number, range_1.from_number)
        update_from_number_or_delete_range(range_1, min_number - 1)
        update_to_number_or_delete_range(range_2, max_number + 1)

      _ ->
        :ok
    end
  end

  def clear_batch(batch) do
    Enum.map(batch, &delete_range/1)
  end

  def save_batch(batch) do
    batch
    |> List.wrap()
    |> Enum.map(&save_range/1)
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

  defp insert_if_needed(%{from_number: from, to_number: to} = params) when from >= to, do: insert_range(params)
  defp insert_if_needed(_params), do: :ok

  defp update_from_number_or_delete_range(%{to_number: to} = range, from) when from < to, do: Repo.delete(range)
  defp update_from_number_or_delete_range(range, from), do: update_range(range, %{from_number: from})

  defp update_to_number_or_delete_range(%{from_number: from} = range, to) when to > from, do: Repo.delete(range)
  defp update_to_number_or_delete_range(range, to), do: update_range(range, %{to_number: to})

  defp get_range_by_block_number(number) do
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
    |> Repo.update_all([])

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
      |> Repo.delete_all()

    intersecting_ranges
  end

  def min_max_block_query do
    from(r in __MODULE__, select: %{min: min(r.to_number), max: max(r.from_number)})
  end

  def get_latest_ranges_query(size) do
    from(r in __MODULE__, order_by: [desc: r.from_number], limit: ^size)
  end

  def from_number_below_query(query \\ __MODULE__, lower_bound) do
    from(r in query, where: r.from_number < ^lower_bound)
  end

  def to_number_above_query(query \\ __MODULE__, upper_bound) do
    from(r in query, where: r.to_number > ^upper_bound)
  end

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

        number, first..last when number == last + 1 ->
          {:cont, first..number}

        number, range ->
          {:cont, range, number..number}
      end,
      fn range -> {:cont, range, nil} end
    )
  end
end
