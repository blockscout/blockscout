defmodule Explorer.Chain.Supply.ExchangeRate do
  @moduledoc """
  Defines the supply API for calculating supply for coins from exchange_rate..
  """

  use Explorer.Chain.Supply

  alias Explorer.ExchangeRates.Token
  alias Explorer.{Chain, Market}

  @wpoa_address "0xD2CFBCDbDF02c42951ad269dcfFa27c02151Cebd"

  def circulating do
    with {:ok, address_hash} <- Chain.string_to_address_hash(@wpoa_address),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      token_decimals_divider =
        10
        |> :math.pow(Decimal.to_integer(address.token.decimals))
        |> Decimal.from_float()

      wpoa_total_supply = Decimal.div(address.token.total_supply, token_decimals_divider)
      available_supply = exchange_rate().available_supply

      circulating_supply = Decimal.sub(available_supply, wpoa_total_supply)

      if Decimal.cmp(circulating_supply, 0) == :gt do
        circulating_supply
      else
        Decimal.new(0)
      end
    else
      _ -> Decimal.new(0)
    end
  end

  def total do
    exchange_rate().total_supply
  end

  def exchange_rate do
    Market.get_exchange_rate(Explorer.coin()) || Token.null()
  end
end
