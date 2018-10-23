defmodule Explorer.ExchangeRates.Source.OneCoinSource do
  @moduledoc false

  alias Explorer.ExchangeRates.Source
  alias Explorer.ExchangeRates.Token

  @behaviour Source

  @impl Source
  def fetch_exchange_rates do
    pseudo_token = %Token{
      available_supply: Decimal.new(10_000_000),
      btc_value: Decimal.new(1),
      id: "",
      last_updated: Timex.now(),
      name: "",
      market_cap_usd: Decimal.new(10_000_000),
      symbol: Explorer.coin(),
      usd_value: Decimal.new(1),
      volume_24h_usd: Decimal.new(1)
    }

    {:ok, [pseudo_token]}
  end
end
