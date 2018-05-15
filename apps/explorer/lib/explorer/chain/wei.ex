defmodule Explorer.Chain.Wei do
  @moduledoc """
  The smallest fractional unit of Ether. Using wei instead of ether allows code to do integer match instead of using
  floats.

  All values represented by the `Wei` struct are assumed to measured in the base unit of wei.
  See [Etherum Homestead Documentation](http://ethdocs.org/en/latest/ether.html) for examples of various denominations of wei.

  Etymology of "wei" comes from [Wei Dai (戴維)](https://en.wikipedia.org/wiki/Wei_Dai), a
  [cypherpunk](https://en.wikipedia.org/wiki/Cypherpunk) who came up with b-money, which outlined modern
  cryptocurrencies.

  ## Interfacing With Ecto

  You can define a field in a schema to be of type Wei for convinience when dealing with Wei values.

      schema "my_schema" do
        field :gas, Explorer.Chain.Wei
      end

  """

  defstruct ~w(value)a

  @behaviour Ecto.Type

  @impl Ecto.Type
  def type, do: :decimal

  @impl Ecto.Type
  def cast("0x" <> hex_wei) do
    with {int_wei, ""} <- Integer.parse(hex_wei, 16) do
      decimal = Decimal.new(int_wei)
      {:ok, %__MODULE__{value: decimal}}
    else
      _ -> :error
    end
  end

  @impl Ecto.Type
  def cast(string_wei) when is_binary(string_wei) do
    with {int_wei, ""} <- Integer.parse(string_wei) do
      decimal = Decimal.new(int_wei)
      {:ok, %__MODULE__{value: decimal}}
    else
      _ -> :error
    end
  end

  @impl Ecto.Type
  def cast(int_wei) when is_integer(int_wei) do
    decimal = Decimal.new(int_wei)
    {:ok, %__MODULE__{value: decimal}}
  end

  @impl Ecto.Type
  def cast(%Decimal{} = decimal) do
    {:ok, %__MODULE__{value: decimal}}
  end

  @impl Ecto.Type
  def cast(%__MODULE__{} = wei) do
    {:ok, wei}
  end

  @impl Ecto.Type
  def cast(_), do: :error

  @impl Ecto.Type
  def dump(%__MODULE__{value: %Decimal{} = decimal}) do
    {:ok, decimal}
  end

  @impl Ecto.Type
  def dump(_), do: :error

  @impl Ecto.Type
  def load(%Decimal{} = decimal) do
    {:ok, %__MODULE__{value: decimal}}
  end

  @typedoc """
  Ether is the default unit Ethereum and its side chains are measured in when displaying values to humans.

  10<sup>18</sup> wei is 1 ether.
  """
  @type ether :: Decimal.t()

  @typedoc """
  Short for giga-wei

  10<sup>9</sup> wei is 1 gwei.
  """
  @type gwei :: Decimal.t()

  @typedoc """
  The unit to convert `t:wei/0` to.
  """
  @type unit :: :wei | :gwei | :ether

  @typedoc """
  The smallest fractional unit of Ether.
  """
  @type wei :: Decimal.t()

  @typedoc @moduledoc
  @type t :: %__MODULE__{
          value: Decimal.t()
        }

  @wei_per_ether Decimal.new(1_000_000_000_000_000_000)
  @wei_per_gwei Decimal.new(1_000_000_000)

  @doc """
  Converts `Decimal` representations of various wei denominations (wei, Gwei, ether) to
  a wei base unit.

  ## Examples

  Convert wei to itself.

      iex> Explorer.Chain.Wei.from(Decimal.new(1), :wei)
      %Explorer.Chain.Wei{value: Decimal.new(1)}

  Convert `t:gwei/0` to wei.

      iex> Explorer.Chain.Wei.from(Decimal.new(1), :gwei)
      %Explorer.Chain.Wei{value: Decimal.new(1_000_000_000)}

  Convert `t:ether/0` to wei.

      iex> Explorer.Chain.Wei.from(Decimal.new(1), :ether)
      %Explorer.Chain.Wei{value: Decimal.new(1_000_000_000_000_000_000)}

  """

  @spec from(ether(), :ether) :: t()
  def from(%Decimal{} = ether, :ether) do
    %__MODULE__{value: Decimal.mult(ether, @wei_per_ether)}
  end

  @spec from(gwei(), :gwei) :: t()
  def from(%Decimal{} = gwei, :gwei) do
    %__MODULE__{value: Decimal.mult(gwei, @wei_per_gwei)}
  end

  @spec from(wei(), :wei) :: t()
  def from(%Decimal{} = wei, :wei) do
    %__MODULE__{value: wei}
  end

  @doc """
  Converts a `Wei` value to another denomination of wei represented in `Decimal`.

  ## Examples

  Convert wei to itself.

      iex> Explorer.Chain.Wei.to(%Explorer.Chain.Wei{value: Decimal.new(1)}, :wei)
      Decimal.new(1)

  Convert wei to `t:gwei/0`.

      iex> Explorer.Chain.Wei.to(%Explorer.Chain.Wei{value: Decimal.new(1)}, :gwei)
      Decimal.new("1e-9")
      iex> Explorer.Chain.Wei.to(%Explorer.Chain.Wei{value: Decimal.new("1e9")}, :gwei)
      Decimal.new(1)

  Convert wei to `t:ether/0`.

      iex> Explorer.Chain.Wei.to(%Explorer.Chain.Wei{value: Decimal.new(1)}, :ether)
      Decimal.new("1e-18")
      iex> Explorer.Chain.Wei.to(%Explorer.Chain.Wei{value: Decimal.new("1e18")}, :ether)
      Decimal.new(1)

  """

  @spec to(t(), :ether) :: ether()
  def to(%__MODULE__{value: wei}, :ether) do
    Decimal.div(wei, @wei_per_ether)
  end

  @spec to(t(), :gwei) :: gwei()
  def to(%__MODULE__{value: wei}, :gwei) do
    Decimal.div(wei, @wei_per_gwei)
  end

  @spec to(t(), :wei) :: t()
  def to(%__MODULE__{value: wei}, :wei), do: wei
end

defimpl Inspect, for: Explorer.Chain.Wei do
  def inspect(wei, _) do
    "#Explorer.Chain.Wei<#{Decimal.to_string(wei.value)}>"
  end
end
