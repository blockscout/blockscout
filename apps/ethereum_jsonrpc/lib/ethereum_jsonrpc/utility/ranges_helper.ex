# credo:disable-for-this-file
defmodule EthereumJSONRPC.Utility.RangesHelper do
  @moduledoc """
  Helper for ranges manipulations.
  """

  @default_trace_block_ranges "0..latest"

  @spec traceable_block_number?(integer() | nil) :: boolean()
  def traceable_block_number?(block_number) do
    if trace_ranges_present?() do
      number_in_ranges?(block_number, get_trace_block_ranges())
    else
      true
    end
  end

  @spec filter_traceable_block_numbers([integer()]) :: [integer()]
  def filter_traceable_block_numbers(block_numbers) do
    if trace_ranges_present?() do
      trace_block_ranges = get_trace_block_ranges()
      Enum.filter(block_numbers, &number_in_ranges?(&1, trace_block_ranges))
    else
      block_numbers
    end
  end

  @spec trace_ranges_present? :: boolean()
  def trace_ranges_present? do
    Application.get_env(:indexer, :trace_block_ranges) != @default_trace_block_ranges
  end

  @spec get_trace_block_ranges :: [Range.t() | integer()]
  def get_trace_block_ranges do
    :indexer
    |> Application.get_env(:trace_block_ranges)
    |> parse_block_ranges()
  end

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

  defp number_in_ranges?(number, ranges) do
    Enum.reduce_while(ranges, false, fn
      _from.._to = range, _acc -> if number in range, do: {:halt, true}, else: {:cont, false}
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

  @spec sanitize_ranges([Range.t() | integer()]) :: [Range.t() | integer()]
  def sanitize_ranges(ranges) do
    ranges
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(
      fn
        from.._to -> from
        el -> el
      end,
      :asc
    )
    |> Enum.chunk_while(
      nil,
      fn
        _from.._to = chunk, nil ->
          {:cont, chunk}

        _ch_from..ch_to = chunk, acc_from..acc_to = acc ->
          if Range.disjoint?(chunk, acc),
            do: {:cont, acc, chunk},
            else: {:cont, acc_from..max(ch_to, acc_to)}

        num, nil ->
          {:halt, num}

        num, acc_from.._ = acc ->
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
    |> Enum.reduce([], fn from..to = range, acc ->
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

  defp parse_integer(string) do
    case Integer.parse(string) do
      {number, ""} -> number
      _ -> nil
    end
  end
end
