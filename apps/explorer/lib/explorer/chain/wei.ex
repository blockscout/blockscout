defmodule Explorer.Chain.Wei do
  @moduledoc """
  The smallest fractional unit of Ether. Using wei instead of ether allows code to do integer match instead of using
  floats.

  Etymology of "wei" comes from [Wei Dai (戴維)](https://en.wikipedia.org/wiki/Wei_Dai), a
  [cypherpunk](https://en.wikipedia.org/wiki/Cypherpunk) who came up with b-money, which outlined modern
  cryptocurrencies.
  """

  @typedoc """
  Ether is the default unit Ethereum and its side chains are measured in when displaying values to humans.

  10<sup>18</sup> wei is 1 ether.
  """
  @type ether :: Decimal.t()

  @typedoc """
  Short for giga-wei

  * 10<sup>9</sup> wei is one gwei
  """
  @type gwei :: Decimal.t()

  @typedoc """
  The unit to convert `t:wei/0` to.
  """
  @type unit :: :wei | :gwei | :ether

  @typedoc @moduledoc
  @type t :: Decimal.t()

  @wei_per_ether Decimal.new(1_000_000_000_000_000_000)
  @wei_per_gwei Decimal.new(1_000_000_000)

  @doc """
  Convert wei to itself.

      iex> Explorer.Chain.Wei.from(Decimal.new(1), :wei)
      Decimal.new(1)

  Convert `t:gwei/0` to wei.

      iex> Explorer.Chain.Wei.from(Decimal.new(1), :gwei)
      Decimal.new(1_000_000_000)

  Convert `t:ether/0` to wei.

      iex> Explorer.Chain.Wei.from(Decimal.new(1), :ether)
      Decimal.new(1_000_000_000_000_000_000)

  """

  @spec from(ether(), :ether) :: t()
  def from(ether, :ether) do
    Decimal.mult(ether, @wei_per_ether)
  end

  @spec from(gwei(), :gwei) :: t()
  def from(gwei, :gwei) do
    Decimal.mult(gwei, @wei_per_gwei)
  end

  @spec from(t(), :wei) :: t()
  def from(wei, :wei), do: wei

  @doc """
  Convert wei to itself.

      iex> Explorer.Chain.Wei.to(Decimal.new(1), :wei)
      Decimal.new(1)

  Convert wei to `t:gwei/0`.

      iex> Explorer.Chain.Wei.to(Decimal.new(1), :gwei)
      Decimal.new("1e-9")
      iex> Explorer.Chain.Wei.to(Decimal.new("1e9"), :gwei)
      Decimal.new(1)

  Convert wei to `t:ether/0`.

      iex> Explorer.Chain.Wei.to(Decimal.new(1), :ether)
      Decimal.new("1e-18")
      iex> Explorer.Chain.Wei.to(Decimal.new("1e18"), :ether)
      Decimal.new(1)

  """

  @spec to(t(), :ether) :: ether()
  def to(wei, :ether) do
    Decimal.div(wei, @wei_per_ether)
  end

  @spec to(t(), :gwei) :: gwei()
  def to(wei, :gwei) do
    Decimal.div(wei, @wei_per_gwei)
  end

  @spec to(t(), :wei) :: t()
  def to(wei, :wei), do: wei
end
