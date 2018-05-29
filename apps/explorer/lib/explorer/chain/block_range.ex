defmodule Explorer.Chain.BlockRange do
  @moduledoc """
  Represents a range of block numbers.
  """

  alias Explorer.Chain.BlockRange
  alias Postgrex.Range

  defstruct [:from, :to]

  @typedoc """
  A block number range where range boundaries are inclusive.

  * `:from` - Lower inclusive bound of range.
  * `:to` - Upper inclusive bound of range.
  """
  @type t :: %BlockRange{
          from: integer() | :negative_infinity,
          to: integer() | :infinity
        }

  @behaviour Ecto.Type

  @impl Ecto.Type
  def type, do: :int8range

  @impl Ecto.Type
  def cast({nil, upper}) when is_integer(upper) do
    {:ok, %BlockRange{from: :negative_infinity, to: upper}}
  end

  def cast({lower, nil}) when is_integer(lower) do
    {:ok, %BlockRange{from: lower, to: :infinity}}
  end

  def cast({lower, upper}) when is_integer(lower) and is_integer(upper) and lower <= upper do
    {:ok, %BlockRange{from: lower, to: upper}}
  end

  def cast(range) when is_binary(range) do
    case Regex.run(~r"([\[\(])(\d*),(\d*)([\]\)])", range, capture: :all_but_first) do
      [lower_boundary, lower, upper, upper_boundary] ->
        block_range = %BlockRange{
          from: cast_lower(lower, lower_boundary),
          to: cast_upper(upper, upper_boundary)
        }

        {:ok, block_range}

      _ ->
        :error
    end
  end

  def cast(%BlockRange{} = block_range), do: {:ok, block_range}

  def cast(_), do: :error

  defp cast_lower("", _symbol), do: :negative_infinity
  defp cast_lower(boundary_value, "["), do: String.to_integer(boundary_value)
  defp cast_lower(boundary_value, "("), do: String.to_integer(boundary_value) + 1

  defp cast_upper("", _symbol), do: :infinity
  defp cast_upper(boundary_value, "]"), do: String.to_integer(boundary_value)
  defp cast_upper(boundary_value, ")"), do: String.to_integer(boundary_value) - 1

  @impl Ecto.Type
  def load(%Range{} = range) do
    block_range = %BlockRange{
      from: parse_lower(range),
      to: parse_upper(range)
    }

    {:ok, block_range}
  end

  def load(_), do: :error

  defp parse_upper(%Range{upper: nil}), do: :infinity
  defp parse_upper(%Range{upper: upper, upper_inclusive: true}), do: upper
  defp parse_upper(%Range{upper: upper, upper_inclusive: false}), do: upper - 1

  defp parse_lower(%Range{lower: nil}), do: :negative_infinity
  defp parse_lower(%Range{lower: lower, lower_inclusive: true}), do: lower
  defp parse_lower(%Range{lower: lower, lower_inclusive: false}), do: lower + 1

  @impl Ecto.Type
  def dump(%BlockRange{from: from, to: to}) do
    upper = build_upper(to)
    lower = build_lower(from)

    range_params = Map.merge(lower, upper)

    {:ok, struct!(Range, range_params)}
  end

  def dump(_), do: :error

  defp build_lower(:negative_infinity) do
    %{lower: nil, lower_inclusive: false}
  end

  defp build_lower(lower) do
    %{lower: lower, lower_inclusive: true}
  end

  defp build_upper(:infinity) do
    %{upper: nil, upper_inclusive: false}
  end

  defp build_upper(upper) do
    %{upper: upper, upper_inclusive: true}
  end
end
