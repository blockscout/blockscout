defmodule BlockScoutWeb.ExchangeRates.USD do
  @moduledoc """
  Struct and associated conversion functions for USD currency
  """

  @typedoc """
  Represents USD currency

  * `:value` - value in USD
  """
  @type t :: %__MODULE__{
          value: Decimal.t() | nil
        }

  defstruct ~w(value)a

  alias Explorer.Chain.Wei
  alias Explorer.ExchangeRates.Token

  def from(nil), do: null()

  def from(%Decimal{} = usd_decimal) do
    %__MODULE__{value: usd_decimal}
  end

  def from(nil, _), do: null()

  def from(_, nil), do: null()

  def from(%Wei{value: nil}, _), do: null()

  def from(_, %Token{usd_value: nil}), do: null()

  def from(%Wei{} = wei, %Token{usd_value: exchange_rate}) do
    ether = Wei.to(wei, :ether)
    %__MODULE__{value: Decimal.mult(ether, exchange_rate)}
  end

  def null do
    %__MODULE__{value: nil}
  end
end
