defmodule Explorer.Market.Source.OneCoinSource do
  @moduledoc false

  alias Explorer.Market.{Source, Token}
  alias Explorer.Chain.Hash

  @behaviour Source

  @coin %Token{
    available_supply: Decimal.new(10_000_000),
    total_supply: Decimal.new(10_000_000_000),
    btc_value: Decimal.new(1),
    last_updated: Timex.now(),
    name: "",
    market_cap: Decimal.new(10_000_000),
    tvl: Decimal.new(100_500_000),
    symbol: Explorer.coin(),
    fiat_value: Decimal.new(1),
    volume_24h: Decimal.new(1),
    image_url: nil
  }

  {:ok, address_hash} = Hash.Address.cast("0x0000000000000000000000000000000000000001")

  @token %{
    contract_address_hash: address_hash,
    type: "ERC-20",
    fiat_value: Decimal.new(1),
    circulating_market_cap: Decimal.new(10_000_000),
    icon_url: nil
  }

  @impl Source
  def native_coin_fetching_enabled?, do: true

  @impl Source
  def fetch_native_coin, do: {:ok, @coin}

  @impl Source
  def secondary_coin_fetching_enabled?, do: true

  @impl Source
  def fetch_secondary_coin, do: {:ok, @coin}

  @impl Source
  def tokens_fetching_enabled?, do: true

  @impl Source
  def fetch_tokens(_state, _batch_size), do: {:ok, nil, true, [@token]}

  @impl Source
  def native_coin_price_history_fetching_enabled?, do: true

  @impl Source
  def fetch_native_coin_price_history(_previous_days),
    do:
      {:ok,
       [%{date: Date.utc_today(), closing_price: Decimal.new(2), opening_price: Decimal.new(1), secondary_coin: false}]}

  @impl Source
  def secondary_coin_price_history_fetching_enabled?, do: true

  @impl Source
  def fetch_secondary_coin_price_history(_previous_days),
    do:
      {:ok,
       [%{date: Date.utc_today(), closing_price: Decimal.new(2), opening_price: Decimal.new(1), secondary_coin: true}]}

  @impl Source
  def market_cap_history_fetching_enabled?, do: true

  @impl Source
  def fetch_market_cap_history(_previous_days), do: {:ok, [%{date: Date.utc_today(), market_cap: Decimal.new(2)}]}

  @impl Source
  def tvl_history_fetching_enabled?, do: true

  @impl Source
  def fetch_tvl_history(_previous_days), do: {:ok, [%{date: Date.utc_today(), tvl: Decimal.new(2)}]}
end
