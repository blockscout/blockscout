defmodule Explorer.ExchangeRates.Rate do
  @moduledoc """
  Data container for modeling an exchange rate.
  """

  @type t :: %__MODULE__{
          last_updated: DateTime.t(),
          ticker_name: String.t(),
          ticker_symbol: String.t(),
          ticker: String.t(),
          usd_value: String.t()
        }

  defstruct ~w(last_updated ticker ticker_name ticker_symbol usd_value)a
end
