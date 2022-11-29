defmodule Explorer.Market do
  @moduledoc """
  Context for data related to the cryptocurrency market.
  """

  alias Explorer.Chain
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Hash
  alias Explorer.ExchangeRates.Token
  alias Explorer.Market.{MarketHistory, MarketHistoryCache}
  alias Explorer.{KnownTokens, Repo}

  @doc """
  Get most recent exchange rate for the given symbol.
  """
  @spec get_exchange_rate(String.t()) :: Token.t() | nil
  def get_exchange_rate(symbol) do
    case {Chain.get_exchange_rate(symbol), Chain.get_exchange_rate("cUSD")} do
      {{:ok, {token, rate}}, {:ok, {_, usd_rate}}} ->
        cusd_rate = Decimal.from_float(rate.rate / usd_rate.rate)
        total_supply = Decimal.div(token.total_supply, Decimal.new("1000000000000000000"))

        Token.from_tuple(
          {symbol, nil, symbol, total_supply, total_supply, cusd_rate, nil, Decimal.mult(cusd_rate, total_supply), nil,
           token.updated_at}
        )

      _ ->
        nil
    end
  end

  @doc """
  Get the address of the token with the given symbol.
  """
  @spec get_known_address(String.t()) :: Hash.Address.t() | nil
  def get_known_address(symbol) do
    case KnownTokens.lookup(symbol) do
      {:ok, address} -> address
      nil -> nil
    end
  end

  @doc """
  Retrieves the history for the recent specified amount of days.

  Today's date is include as part of the day count
  """
  @spec fetch_recent_history() :: [MarketHistory.t()]
  def fetch_recent_history do
    MarketHistoryCache.fetch()
  end

  @doc false
  def bulk_insert_history(records) do
    records_without_zeroes =
      records
      |> Enum.reject(fn item ->
        Decimal.equal?(item.closing_price, 0) && Decimal.equal?(item.opening_price, 0)
      end)
      # Enforce MarketHistory ShareLocks order (see docs: sharelocks.md)
      |> Enum.sort_by(& &1.date)

    Repo.insert_all(MarketHistory, records_without_zeroes, on_conflict: :nothing, conflict_target: [:date])
  end

  def add_price(%{symbol: symbol} = token) do
    known_address = get_known_address(symbol)

    matches_known_address = known_address && known_address == token.contract_address_hash

    usd_value =
      if matches_known_address do
        fetch_token_usd_value(matches_known_address, symbol)
      else
        nil
      end

    Map.put(token, :usd_value, usd_value)
  end

  def add_price(%CurrentTokenBalance{token: token} = token_balance) do
    token_with_price = add_price(token)

    Map.put(token_balance, :token, token_with_price)
  end

  def add_price(tokens) when is_list(tokens) do
    Enum.map(tokens, fn item ->
      case item do
        {token_balance, token} ->
          {add_price(token_balance), token}

        token_balance ->
          add_price(token_balance)
      end
    end)
  end

  defp fetch_token_usd_value(true, symbol) do
    case get_exchange_rate(symbol) do
      %{usd_value: usd_value} -> usd_value
      nil -> nil
    end
  end

  defp fetch_token_usd_value(_matches_known_address, _symbol), do: nil
end
