defmodule Explorer.Market do
  @moduledoc """
  Context for data related to the cryptocurrency market.
  """

  use GenServer

  require Logger
  alias Explorer.Helper
  alias Explorer.Market.Fetcher.Coin, as: CoinFetcher
  alias Explorer.Market.Fetcher.History, as: HistoryFetcher
  alias Explorer.Market.Fetcher.Token, as: TokenFetcher

  alias Explorer.Market.{MarketHistory, MarketHistoryCache, Token}

  @history_key :market_history_fetcher_enabled
  @tokens_key :market_token_fetcher_enabled

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    if Explorer.mode() == :all do
      {history_pid, token_pid} = find_history_and_token_fetchers()
      :persistent_term.put(@history_key, !is_nil(history_pid))
      :persistent_term.put(@tokens_key, !is_nil(token_pid))
      :ignore
    else
      {:ok, nil, {:continue, 1}}
    end
  end

  @impl GenServer
  def handle_continue(attempt, _state) do
    attempt |> Kernel.**(3) |> :timer.seconds() |> :timer.sleep()

    case Node.list()
         |> Enum.filter(&Helper.indexer_node?/1) do
      [] ->
        if attempt < 5 do
          {:noreply, nil, {:continue, attempt + 1}}
        else
          raise "No indexer nodes discovered after #{attempt} attempts"
        end

      [indexer] ->
        {history_pid, token_pid} =
          indexer
          |> :rpc.call(__MODULE__, :find_history_and_token_fetchers, [])
          |> Helper.process_rpc_response(indexer, {nil, nil})

        :persistent_term.put(@history_key, !is_nil(history_pid))
        :persistent_term.put(@tokens_key, !is_nil(token_pid))
        {:stop, :normal, nil}

      multiple_indexers ->
        if attempt < 5 do
          {:noreply, nil, {:continue, attempt + 1}}
        else
          raise "Multiple indexer nodes discovered: #{inspect(multiple_indexers)}"
        end
    end
  end

  @doc """
  Retrieves the history for the recent specified amount of days.

  Today's date is include as part of the day count
  """
  @spec fetch_recent_history(boolean()) :: [MarketHistory.t()]
  def fetch_recent_history(secondary_coin? \\ false) do
    if history_fetcher_enabled?() do
      MarketHistoryCache.fetch(secondary_coin?)
    else
      []
    end
  end

  @doc """
  Get most recent exchange rate for the native coin from ETS or from DB.
  """
  @spec get_coin_exchange_rate() :: Token.t()
  def get_coin_exchange_rate do
    CoinFetcher.get_coin_exchange_rate() || Token.null()
  end

  @doc """
  Get most recent exchange rate for the secondary coin from DB.
  """
  @spec get_secondary_coin_exchange_rate() :: Token.t()
  def get_secondary_coin_exchange_rate do
    CoinFetcher.get_secondary_coin_exchange_rate() || Token.null()
  end

  @doc """
  Retrieves the token exchange rate information for a specific date.

  This function fetches historical market data for a given datetime and constructs
  a token record with price information. If the datetime is nil or no market
  history exists for the specified date, returns a null token record.

  ## Parameters
  - `datetime`: The datetime for which to retrieve the exchange rate. If nil,
    returns a null token record.
  - `options`: Additional options for retrieving market history data.

  ## Returns
  - A `Token` struct containing the closing price as fiat value, market cap, and
    TVL from the market history. All other token fields are set to nil.
  - A null token record if datetime is nil or no market history exists for the
    specified date.
  """
  @spec get_coin_exchange_rate_at_date(DateTime.t() | nil, Keyword.t()) :: Token.t()
  def get_coin_exchange_rate_at_date(nil, _options), do: Token.null()

  def get_coin_exchange_rate_at_date(datetime, options) do
    datetime
    |> DateTime.to_date()
    |> MarketHistory.price_at_date(false, options)
    |> MarketHistory.to_token()
  end

  @doc """
  Checks if the market token fetcher is enabled in the application.

  This function retrieves the enablement status from persistent term storage
  using the `:market_token_fetcher_enabled` key. If the key is not set, it
  defaults to `false`.

  ## Returns
  - `true` if the market token fetcher is enabled
  - `false` if the market token fetcher is disabled or not configured
  """
  @spec token_fetcher_enabled?() :: boolean()
  def token_fetcher_enabled? do
    :persistent_term.get(@tokens_key, false)
  end

  @spec history_fetcher_enabled?() :: boolean()
  defp history_fetcher_enabled? do
    :persistent_term.get(@history_key, false)
  end

  @doc """
  Locates the running processes for the market history and token fiat value fetchers.

  This function checks whether the `Explorer.Market.Fetcher.History` and
  `Explorer.Market.Fetcher.Token` GenServer processes are currently running
  and returns their process identifiers.

  ## Parameters
  None.

  ## Returns
  - A tuple `{history_fetcher, token_fetcher}` where each element is:
    - `nil` if the corresponding fetcher process is not running
    - A `pid()` if the process is registered locally
    - A `{atom(), atom()}` tuple if registered via `:global` or `:via`
  """
  @spec find_history_and_token_fetchers() :: {nil | pid() | {atom(), atom()}, nil | pid() | {atom(), atom()}}
  def find_history_and_token_fetchers, do: {GenServer.whereis(HistoryFetcher), GenServer.whereis(TokenFetcher)}
end
