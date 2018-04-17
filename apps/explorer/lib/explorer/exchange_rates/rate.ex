defmodule Explorer.ExchangeRates.Rate do
  @moduledoc """
  Data container for modeling an exchange rate.
  """

  @typedoc """
  Represents an exchange rate for a given currency.

  * `:id` - ID of a currency
  * `:last_updated` - Timestamp of when the value was last updated
  * `:name` - Human-readable name of a ticker
  * `:symbol` - Trading symbol used to represent a currency
  * `:usd_value` - The USD value of the currency
  """
  @type t :: %__MODULE__{
          id: String.t(),
          last_updated: DateTime.t(),
          name: String.t(),
          symbol: String.t(),
          usd_value: String.t()
        }

  defstruct ~w(id last_updated name symbol usd_value)a
end
