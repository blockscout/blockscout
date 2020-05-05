defmodule Explorer.Chain.Block.Range do
  @moduledoc """
  Represents a range of block numbers.
  """

  alias Explorer.Chain.Block.Range
  alias Postgrex.Range, as: PGRange

  defstruct [:from, :to]

  @typedoc """
  A block number range where range boundaries are inclusive.

  * `:from` - Lower inclusive bound of range.
  * `:to` - Upper inclusive bound of range.
  """
  @type t :: %Range{
          from: integer() | :negative_infinity,
          to: integer() | :infinity
        }

  use Ecto.Type

  @doc """
  The underlying Postgres type, `int8range`.
  """
  @impl Ecto.Type
  def type, do: :int8range

  @doc """
  Converts a value to a `Range`.

  ## Examples

  Tuples of integers

      iex> cast({1, 5})
      {:ok, %Range{from: 1, to: 5}}

      iex> cast({nil, 5})
      {:ok, %Range{from: :negative_infinity, to: 5}}

      iex> cast({1, nil})
      {:ok, %Range{from: 1, to: :infinity}}

  Postgres range strings

      iex> cast("[1,5]")
      {:ok, %Range{from: 1, to: 5}}

      iex> cast("(0,6)")
      {:ok, %Range{from: 1, to: 5}}

      iex> cast("(,5]")
      {:ok, %Range{from: :negative_infinity, to: 5}}

      iex> cast("[1,)")
      {:ok, %Range{from: 1, to: :infinity}}

  Range

      iex> cast(%Range{from: 1, to: 5})
      {:ok, %Range{from: 1, to: 5}}
  """
  @impl Ecto.Type
  def cast({nil, upper}) when is_integer(upper) do
    {:ok, %Range{from: :negative_infinity, to: upper}}
  end

  def cast({lower, nil}) when is_integer(lower) do
    {:ok, %Range{from: lower, to: :infinity}}
  end

  def cast({lower, upper}) when is_integer(lower) and is_integer(upper) and lower <= upper do
    {:ok, %Range{from: lower, to: upper}}
  end

  def cast(range_string) when is_binary(range_string) do
    # Lower boundary should be either `[` or `(`
    lower_boundary_values = "[\\[\\(]"
    # Integer may or may not be present
    integer = "\\d*"
    # Upper boundary should be either `]` or `)`
    upper_boundary_values = "[\\]\\)]"
    range_regex = ~r"(#{lower_boundary_values})(#{integer}),(#{integer})(#{upper_boundary_values})"

    case Regex.run(range_regex, range_string, capture: :all_but_first) do
      [lower_boundary, lower, upper, upper_boundary] ->
        block_range = %Range{
          from: cast_lower(lower, lower_boundary),
          to: cast_upper(upper, upper_boundary)
        }

        {:ok, block_range}

      _ ->
        :error
    end
  end

  def cast(%Range{} = block_range), do: {:ok, block_range}

  def cast(_), do: :error

  defp cast_lower("", _symbol), do: :negative_infinity
  defp cast_lower(boundary_value, "["), do: String.to_integer(boundary_value)
  defp cast_lower(boundary_value, "("), do: String.to_integer(boundary_value) + 1

  defp cast_upper("", _symbol), do: :infinity
  defp cast_upper(boundary_value, "]"), do: String.to_integer(boundary_value)
  defp cast_upper(boundary_value, ")"), do: String.to_integer(boundary_value) - 1

  @doc """
  Loads a range from the database and converts it to a `t:Range.t.0`.

  ## Example

      iex> pg_range = %Postgrex.Range{
      ...>   lower: 1,
      ...>   lower_inclusive: true,
      ...>   upper: 5,
      ...>   upper_inclusive: true
      ...> }
      iex> load(pg_range)
      {:ok, %Range{from: 1, to: 5}}
  """
  @impl Ecto.Type
  def load(%PGRange{} = range) do
    block_range = %Range{
      from: parse_lower(range),
      to: parse_upper(range)
    }

    {:ok, block_range}
  end

  def load(_), do: :error

  defp parse_upper(%PGRange{upper: :unbound}), do: :infinity
  defp parse_upper(%PGRange{upper: nil}), do: :infinity
  defp parse_upper(%PGRange{upper: upper, upper_inclusive: true}), do: upper
  defp parse_upper(%PGRange{upper: upper, upper_inclusive: false}), do: upper - 1

  defp parse_upper(%PGRange{lower: :unbound}), do: :negative_infinity
  defp parse_lower(%PGRange{lower: nil}), do: :negative_infinity
  defp parse_lower(%PGRange{lower: lower, lower_inclusive: true}), do: lower
  defp parse_lower(%PGRange{lower: lower, lower_inclusive: false}), do: lower + 1

  @doc """
  Converts a `t:Range.t/0` to a persistable data value.

  ## Example

      iex> dump(%Range{from: 1, to: 5})
      {:ok,
       %Postgrex.Range{
         lower: 1,
         lower_inclusive: true,
         upper: 5,
         upper_inclusive: true
       }}
  """
  @impl Ecto.Type
  def dump(%Range{from: from, to: to}) do
    upper = build_upper(to)
    lower = build_lower(from)

    range_params = Map.merge(lower, upper)

    {:ok, struct!(PGRange, range_params)}
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
