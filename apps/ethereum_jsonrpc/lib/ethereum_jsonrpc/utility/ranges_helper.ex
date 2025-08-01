# credo:disable-for-this-file
defmodule EthereumJSONRPC.Utility.RangesHelper do
  @moduledoc """
  Helper for ranges manipulations.
  """

  @default_trace_block_ranges "0..latest"

  @doc """
  Checks if block number is traceable
  """
  @spec traceable_block_number?(integer() | nil) :: boolean()
  def traceable_block_number?(block_number) do
    if trace_ranges_present?() do
      number_in_ranges?(block_number, get_trace_block_ranges())
    else
      true
    end
  end

  @doc """
  Filters out non-traceable records from `data` by its block number
  """
  @spec filter_traceable_block_numbers([integer() | map()]) :: [integer() | map()]
  def filter_traceable_block_numbers(data) do
    if trace_ranges_present?() do
      trace_block_ranges = get_trace_block_ranges()
      Enum.filter(data, &number_in_ranges?(extract_block_number(&1), trace_block_ranges))
    else
      data
    end
  end

  @doc """
  Filters elements with `filter_func` if `TRACE_BLOCK_RANGES` is set
  """
  @spec filter_by_height_range([any()], (any() -> boolean())) :: [any()]
  def filter_by_height_range(elements, filter_func) do
    if trace_ranges_present?() do
      Enum.filter(elements, &filter_func.(&1))
    else
      elements
    end
  end

  @doc """
  Checks if trace ranges are defined via env variables
  """
  @spec trace_ranges_present? :: boolean()
  def trace_ranges_present? do
    Application.get_env(:indexer, :trace_block_ranges) != @default_trace_block_ranges
  end

  @doc """
  Retrieves trace ranges from application variable in string format and parses them into Range/integer
  """
  @spec get_trace_block_ranges :: [Range.t() | integer()]
  def get_trace_block_ranges do
    :indexer
    |> Application.get_env(:trace_block_ranges)
    |> parse_block_ranges()
  end

  @doc """
  Parse ranges from string format into Range/integer
  """
  @spec parse_block_ranges(binary()) :: [Range.t() | integer()]
  def parse_block_ranges(block_ranges_string) do
    block_ranges_string
    |> String.split(",")
    |> Enum.map(fn string_range ->
      case String.split(string_range, "..") do
        [from_string, "latest"] ->
          parse_integer(from_string)

        [from_string, to_string] ->
          get_from_to(from_string, to_string)

        _ ->
          nil
      end
    end)
    |> sanitize_ranges()
  end

  @doc """
  Extracts the minimum block number from a given block ranges string.

  ## Parameters

    - block_ranges_string: A string representing block ranges.

  ## Returns

    - The minimum block number as an integer.

  ## Examples

      iex> get_min_block_number_from_range_string("100..200,300..400")
      100

  """
  @spec get_min_block_number_from_range_string(binary()) :: integer()
  def get_min_block_number_from_range_string(block_ranges_string) do
    min_block_number =
      case block_ranges_string
           |> parse_block_ranges()
           |> Enum.at(0) do
        block_number.._//_ -> block_number
        block_number -> block_number
      end

    min_block_number
  end

  @doc """
  Checks if `number` is present in `ranges`
  """
  @spec number_in_ranges?(integer(), [Range.t()]) :: boolean()
  def number_in_ranges?(number, ranges) do
    Enum.reduce_while(ranges, false, fn
      _from.._to//_ = range, _acc -> if number in range, do: {:halt, true}, else: {:cont, false}
      num_to_latest, _acc -> if number >= num_to_latest, do: {:halt, true}, else: {:cont, false}
    end)
  end

  defp get_from_to(from_string, to_string) do
    with {from, ""} <- Integer.parse(from_string),
         {to, ""} <- Integer.parse(to_string) do
      if from <= to, do: from..to, else: nil
    else
      _ -> nil
    end
  end

  @doc """
  Rejects empty ranges and merges adjacent ranges
  """
  @spec sanitize_ranges([Range.t() | integer()]) :: [Range.t() | integer()]
  def sanitize_ranges(ranges) do
    ranges
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(
      fn
        from.._to//_ -> from
        el -> el
      end,
      :asc
    )
    |> Enum.chunk_while(
      nil,
      fn
        _from.._to//_ = chunk, nil ->
          {:cont, chunk}

        _ch_from..ch_to//_ = chunk, acc_from..acc_to//_ = acc ->
          if Range.disjoint?(chunk, acc),
            do: {:cont, acc, chunk},
            else: {:cont, acc_from..max(ch_to, acc_to)}

        num, nil ->
          {:halt, num}

        num, acc_from.._//_ = acc ->
          if Range.disjoint?(num..num, acc), do: {:cont, acc, num}, else: {:halt, acc_from}

        _, num ->
          {:halt, num}
      end,
      fn remainder -> {:cont, remainder, nil} end
    )
  end

  @doc """
  Converts initial ranges to ranges with size less or equal to the given size
  """
  @spec split([Range.t()], integer) :: [Range.t()]
  def split(ranges, size) do
    ranges
    |> Enum.reduce([], fn from..to//_ = range, acc ->
      range_size = Range.size(range)

      if range_size > size do
        Enum.reduce(Range.new(0, range_size - 1, size), acc, fn iterator, inner_acc ->
          start_from = from - iterator
          [Range.new(start_from, max(start_from - size + 1, to), -1) | inner_acc]
        end)
      else
        [range | acc]
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Defines a stream reducer that filters out data with non-traceable block number.
  Applicable for fetchers' `init` function (for modules that implement `BufferedTask`).
  """
  @spec stream_reducer_traceable((any(), any() -> any())) :: (any(), any() -> any())
  def stream_reducer_traceable(reducer) do
    if trace_ranges_present?() do
      trace_block_ranges = get_trace_block_ranges()

      fn data, acc ->
        if number_in_ranges?(extract_block_number(data), trace_block_ranges),
          do: reducer.(data, acc),
          else: acc
      end
    else
      fn block_number, acc ->
        reducer.(block_number, acc)
      end
    end
  end

  defp extract_block_number(%{block_number: block_number}), do: block_number
  defp extract_block_number(block_number), do: block_number

  defp parse_integer(string) do
    case Integer.parse(string) do
      {number, ""} -> number
      _ -> nil
    end
  end
end
