defmodule Explorer.ExchangeRates.Token do
  @moduledoc """
  Data container for modeling an exchange rate for a currency/token.
  """

  @typedoc """
  Represents an exchange rate for a given token.

   * `:available_supply` - Available supply of a token
   * `:btc_value` - The Bitcoin value of the currency
   * `:id` - ID of a currency
   * `:last_updated` - Timestamp of when the value was last updated
   * `:market_cap_usd` - Market capitalization of the currency
   * `:name` - Human-readable name of a ticker
   * `:symbol` - Trading symbol used to represent a currency
   * `:usd_value` - The USD value of the currency
   * `:volume_24h_usd` - The volume from the last 24 hours in USD
  """
  @type t :: %__MODULE__{
          available_supply: Decimal.t(),
          btc_value: Decimal.t(),
          id: String.t(),
          last_updated: DateTime.t(),
          market_cap_usd: Decimal.t(),
          name: String.t(),
          symbol: String.t(),
          usd_value: Decimal.t(),
          volume_24h_usd: Decimal.t()
        }

  defstruct ~w(available_supply btc_value id last_updated market_cap_usd name symbol usd_value volume_24h_usd)a

  def null, do: %__MODULE__{}
end
