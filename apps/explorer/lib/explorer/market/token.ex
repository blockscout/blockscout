defmodule Explorer.Market.Token do
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
   * `:market_cap` - Market capitalization of the currency
   * `:tvl` - Token value locked of the currency
   * `:name` - Human-readable name of a ticker
   * `:symbol` - Trading symbol used to represent a currency
   * `:fiat_value` - The fiat value of the currency
   * `:volume_24h` - The volume from the last 24 hours
   * `:image_url` - Token image URL
  """
  @type t :: %__MODULE__{
          available_supply: Decimal.t() | nil,
          total_supply: Decimal.t() | nil,
          btc_value: Decimal.t() | nil,
          last_updated: DateTime.t() | nil,
          market_cap: Decimal.t() | nil,
          tvl: Decimal.t() | nil,
          name: String.t() | nil,
          symbol: String.t() | nil,
          fiat_value: Decimal.t() | nil,
          volume_24h: Decimal.t() | nil,
          image_url: String.t() | nil
        }

  @derive Jason.Encoder
  @enforce_keys ~w(available_supply total_supply btc_value last_updated market_cap tvl name symbol fiat_value volume_24h image_url)a
  defstruct ~w(available_supply total_supply btc_value last_updated market_cap tvl name symbol fiat_value volume_24h image_url)a

  def null,
    do: %__MODULE__{
      available_supply: nil,
      total_supply: nil,
      btc_value: nil,
      last_updated: nil,
      market_cap: nil,
      tvl: nil,
      name: nil,
      symbol: nil,
      fiat_value: nil,
      volume_24h: nil,
      image_url: nil
    }

  def null?(token), do: token == null()
end
