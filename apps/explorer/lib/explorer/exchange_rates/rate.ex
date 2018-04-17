defmodule Explorer.ExchangeRates.Rate do
  @moduledoc """
  Data container for modeling an exchange rate.
  """

  @typedoc """
  Represents an exchange rate for a given currency.

  * `:btc_value` - The Bitcoin value of the currency
  * `:id` - ID of a currency
  * `:last_updated` - Timestamp of when the value was last updated
  * `:market_cap_usd` - Market capitalization of the currency
  * `:name` - Human-readable name of a ticker
  * `:symbol` - Trading symbol used to represent a currency
  * `:usd_value` - The USD value of the currency
  """
  @type t :: %__MODULE__{
          btc_value: String.t(),
          id: String.t(),
          last_updated: DateTime.t(),
          market_cap_usd: String.t(),
          name: String.t(),
          symbol: String.t(),
          usd_value: String.t()
        }

  defstruct ~w(btc_value id last_updated market_cap_usd name symbol usd_value)a
end
