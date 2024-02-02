defmodule Explorer.ExchangeRates.Token do
  @moduledoc """
  Data container for modeling an exchange rate for a currency/token.
  """

  @typedoc """
  Represents an exchange rate for a given token.

   * `:available_supply` - Available supply of a token
   * `:total_supply` - Max Supply
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
          total_supply: Decimal.t(),
          btc_value: Decimal.t(),
          id: String.t(),
          last_updated: DateTime.t(),
          market_cap_usd: Decimal.t(),
          name: String.t(),
          symbol: String.t(),
          usd_value: Decimal.t(),
          volume_24h_usd: Decimal.t()
        }

  @derive Jason.Encoder
  @enforce_keys ~w(available_supply total_supply btc_value id last_updated market_cap_usd name symbol usd_value volume_24h_usd)a
  defstruct ~w(available_supply total_supply btc_value id last_updated market_cap_usd name symbol usd_value volume_24h_usd)a

  def null,
    do: %__MODULE__{
      symbol: nil,
      id: nil,
      name: nil,
      available_supply: nil,
      total_supply: nil,
      usd_value: nil,
      volume_24h_usd: nil,
      market_cap_usd: nil,
      btc_value: nil,
      last_updated: nil
    }

  def null?(token), do: token == null()

  def to_tuple(%__MODULE__{
        symbol: symbol,
        id: id,
        name: name,
        available_supply: available_supply,
        total_supply: total_supply,
        usd_value: usd_value,
        volume_24h_usd: volume_24h_usd,
        market_cap_usd: market_cap_usd,
        btc_value: btc_value,
        last_updated: last_updated
      }) do
    # symbol is first because it is the key used for lookup in `Explorer.ExchangeRates`'s ETS table
    {symbol, id, name, available_supply, total_supply, usd_value, volume_24h_usd, market_cap_usd, btc_value,
     last_updated}
  end

  def from_tuple(
        {symbol, id, name, available_supply, total_supply, usd_value, volume_24h_usd, market_cap_usd, btc_value,
         last_updated}
      ) do
    %__MODULE__{
      symbol: symbol,
      id: id,
      name: name,
      available_supply: available_supply,
      total_supply: total_supply,
      usd_value: usd_value,
      volume_24h_usd: volume_24h_usd,
      market_cap_usd: market_cap_usd,
      btc_value: btc_value,
      last_updated: last_updated
    }
  end
end
