defmodule Explorer.Market.Source do
  @moduledoc """
  Defines behaviors and utilities for fetching cryptocurrency market data from multiple sources.

  This module provides a comprehensive interface for retrieving market data including:
  - Native and secondary coin information
  - Token details
  - Price history
  - Market capitalization history
  - Total Value Locked (TVL) history

  The module supports multiple data providers through behavior callbacks:
  - CoinGecko
  - CoinMarketCap
  - CryptoCompare
  - CryptoRank
  - DefiLlama
  - Mobula

  Each data source can implement specific callbacks based on its capabilities:
  - Native coin data fetching
  - Secondary coin data fetching
  - Token data fetching
  - Price history retrieval
  - Market cap history retrieval
  - TVL history retrieval

  The module also provides utility functions for:
  - Making HTTP requests with proper error handling
  - Processing dates and URLs
  - Converting values to Decimal type
  - Configuring and selecting appropriate data sources for different types of market
    data
  """

  alias Explorer.Chain.Hash
  alias Explorer.{Helper, HttpClient}

  alias Explorer.Market.Source.{
    CoinGecko,
    CoinMarketCap,
    CryptoCompare,
    CryptoRank,
    DefiLlama,
    Mobula
  }

  alias Explorer.Market.Token

  # Native coin processing
  @callback native_coin_fetching_enabled?() :: boolean() | :ignore
  @callback fetch_native_coin() :: {:ok, Token.t()} | {:error, any()} | :ignore

  # Secondary coin processing
  @callback secondary_coin_fetching_enabled?() :: boolean() | :ignore
  @callback fetch_secondary_coin() :: {:ok, Token.t()} | {:error, any()} | :ignore

  # Tokens processing
  @type state() :: any()
  @type fetch_finished?() :: boolean()
  @callback tokens_fetching_enabled?() :: boolean() | :ignore
  @callback fetch_tokens(state() | nil, non_neg_integer()) ::
              {:ok, state(), fetch_finished?(), [token_params]} | {:error, any()} | :ignore
            when token_params: %{
                   required(:contract_address_hash) => Hash.Address.t(),
                   required(:type) => String.t(),
                   optional(any()) => any()
                 }

  # Price history processing
  @type history_price_record() :: %{
          closing_price: Decimal.t(),
          date: Date.t(),
          opening_price: Decimal.t(),
          secondary_coin: boolean()
        }

  @callback native_coin_price_history_fetching_enabled?() :: boolean() | :ignore
  @callback fetch_native_coin_price_history(previous_days :: non_neg_integer()) ::
              {:ok, [history_price_record()]} | {:error, any()} | :ignore

  @callback secondary_coin_price_history_fetching_enabled?() :: boolean() | :ignore
  @callback fetch_secondary_coin_price_history(previous_days :: non_neg_integer()) ::
              {:ok, [history_price_record()]} | {:error, any()} | :ignore

  # Market cap history processing
  @type history_market_cap_record() :: %{
          date: Date.t(),
          market_cap: Decimal.t()
        }

  @callback market_cap_history_fetching_enabled?() :: boolean() | :ignore
  @callback fetch_market_cap_history(previous_days :: non_neg_integer()) ::
              {:ok, [history_market_cap_record()]} | {:error, any()} | :ignore

  # TVL history processing
  @type history_tvl_record() :: %{
          date: Date.t(),
          tvl: Decimal.t()
        }

  @callback tvl_history_fetching_enabled?() :: boolean() | :ignore
  @callback fetch_tvl_history(previous_days :: non_neg_integer()) ::
              {:ok, [history_tvl_record()]} | {:error, any()} | :ignore

  @doc """
  Performs an HTTP GET request to the specified URL and processes the response.

  Makes a GET request with JSON content-type header and processes the response based
  on the status code. Successfully retrieved data is JSON-decoded with special
  handling for NFT-related responses. Error responses are formatted into descriptive
  error messages.

  ## Parameters
  - `source_url`: The URL to send the GET request to
  - `additional_headers`: Extra HTTP headers to be added to the default JSON
    content-type header

  ## Returns
  - `{:ok, decoded_data}` if the request succeeds with status 200 and valid JSON
    response
  - `{:error, reason}` in the following cases:
    - Status 300-308: reason will be "Source redirected"
    - Status 400-526: reason will be "status_code: error_message" from the response
    - Other status codes: reason will be "Source unexpected status code"
    - HTTP client errors: reason will be the underlying error
    - JSON decoding errors: reason will be the raw response body
  """
  @spec http_request(String.t(), [{atom() | binary(), binary()}]) :: {:ok, any()} | {:error, any()}
  def http_request(source_url, additional_headers) do
    case HttpClient.get(source_url, headers() ++ additional_headers) do
      {:ok, %{body: body, status_code: 200}} ->
        parse_http_success_response(body)

      {:ok, %{body: body, status_code: status_code}} when status_code in 400..526 ->
        {:error, "#{status_code}: #{body}"}

      {:ok, %{status_code: status_code}} when status_code in 300..308 ->
        {:error, "Source redirected"}

      {:ok, %{status_code: _status_code}} ->
        {:error, "Source unexpected status code"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_http_success_response(body) do
    case Helper.decode_json(body, true) do
      {:error, _reason} = error -> error
      body_json -> {:ok, body_json}
    end
  end

  defp headers do
    [{"Content-Type", "application/json"}]
  end

  @doc """
  Returns `nil` if the date is `nil` or invalid, otherwise returns the parsed date.
  Date should be in ISO8601 format
  """
  @spec maybe_get_date(String.t() | nil) :: DateTime.t() | nil
  def maybe_get_date(nil), do: nil

  def maybe_get_date(date) do
    case DateTime.from_iso8601(date) do
      {:ok, parsed_date, _} -> parsed_date
      _ -> nil
    end
  end

  @doc """
  Returns `nil` if the url is invalid, otherwise returns the parsed url.
  """
  @spec handle_image_url(String.t() | nil) :: String.t() | nil
  def handle_image_url(nil), do: nil

  def handle_image_url(url) do
    case Helper.validate_url(url) do
      {:ok, url} -> url
      _ -> nil
    end
  end

  @doc """
  Converts a value into a Decimal number or returns nil if the input is nil.

  This function provides a safe way to convert various numeric types and their
  string representations into Decimal numbers while preserving the exactness of
  the input when possible. Float conversions may have precision limitations
  inherent to floating-point arithmetic.

  ## Parameters
  - `value`: The value to convert. Can be one of:
    * `nil` - returned as is
    * `Decimal.t()` - returned as is
    * `float()` - converted using floating-point arithmetic
    * `integer()` - converted exactly
    * `String.t()` - parsed exactly according to Decimal string format

  ## Returns
  - `nil` if the input is `nil`
  - `Decimal.t()` representing the input value

  ## Examples

      iex> to_decimal(nil)
      nil

      iex> to_decimal(Decimal.new("1.23"))
      Decimal.new("1.23")

      iex> to_decimal(3.14)
      Decimal.new("3.14")

      iex> to_decimal(42)
      Decimal.new("42")

      iex> to_decimal("123.45")
      Decimal.new("123.45")
  """
  @spec to_decimal(float() | integer() | Decimal.t() | String.t() | nil) :: Decimal.t() | nil
  def to_decimal(nil), do: nil

  def to_decimal(%Decimal{} = value), do: value

  def to_decimal(value) when is_float(value) do
    Decimal.from_float(value)
  end

  def to_decimal(value) when is_integer(value) or is_binary(value) do
    Decimal.new(value)
  end

  @sources [CoinGecko, CoinMarketCap, CryptoCompare, CryptoRank, DefiLlama, Mobula]

  @doc """
  Returns a module for fetching native coin market data.

  Uses configured source or finds the first available provider with token fetching
  enabled.

  ## Returns
  - A module ready to fetch data, or
  - `nil` if no source is available
  """
  @spec native_coin_source() :: module
  def native_coin_source do
    config(:native_coin_source) || Enum.find(@sources, fn source -> source.native_coin_fetching_enabled?() == true end)
  end

  @doc """
  Returns a module for fetching secondary coin market data.

  Used when tracking two different coins simultaneously. Uses configured source or
  finds the first available provider with token fetching enabled.

  ## Returns
  - A module ready to fetch data, or
  - `nil` if no source is available
  """
  @spec secondary_coin_source() :: module
  def secondary_coin_source do
    config(:secondary_coin_source) ||
      Enum.find(@sources, fn source -> source.secondary_coin_fetching_enabled?() == true end)
  end

  @doc """
  Returns a module for fetching token market data.

  Unlike native/secondary coins, this fetches data for smart contracts
  implementing token interface. Uses configured source or finds the first
  available provider.

  ## Returns
  - A module ready to fetch data, or
  - `nil` if no source is available
  """
  @spec tokens_source() :: module
  def tokens_source do
    config(:tokens_source) || Enum.find(@sources, fn source -> source.tokens_fetching_enabled?() == true end)
  end

  @doc """
  Returns a module for fetching native coin price history.

  Uses configured source or finds the first available provider, preferring
  CryptoCompare as the default source.

  ## Returns
  - A module ready to fetch data, or
  - `nil` if no source is available
  """
  @spec native_coin_price_history_source() :: module
  def native_coin_price_history_source do
    config(:native_coin_history_source) ||
      Enum.find([CryptoCompare | @sources], fn source ->
        source.native_coin_price_history_fetching_enabled?() == true
      end)
  end

  @doc """
  Returns a module for fetching secondary coin price history.

  Uses configured source or finds the first available provider, preferring
  CryptoCompare as the default source.

  ## Returns
  - A module ready to fetch data, or
  - `nil` if no source is available
  """
  @spec secondary_coin_price_history_source() :: module
  def secondary_coin_price_history_source do
    config(:secondary_coin_history_source) ||
      Enum.find([CryptoCompare | @sources], fn source ->
        source.secondary_coin_price_history_fetching_enabled?() == true
      end)
  end

  @doc """
  Returns a module for fetching coin market capitalization history.

  Uses configured source or finds the first available provider with market cap
  history fetching enabled.

  ## Returns
  - A module ready to fetch data, or
  - `nil` if no source is available
  """
  @spec market_cap_history_source() :: module
  def market_cap_history_source do
    config(:market_cap_history_source) ||
      Enum.find(@sources, fn source -> source.market_cap_history_fetching_enabled?() == true end)
  end

  @doc """
  Returns a module for fetching Total Value Locked (TVL) history.

  Uses configured source or finds the first available provider, preferring
  DefiLlama as the default source.

  ## Returns
  - A module ready to fetch data, or
  - `nil` if no source is available
  """
  @spec tvl_history_source() :: module
  def tvl_history_source do
    config(:tvl_history_source) ||
      Enum.find([DefiLlama | @sources], fn source -> source.tvl_history_fetching_enabled?() == true end)
  end

  @spec secondary_coin_string(boolean()) :: String.t()
  def secondary_coin_string(secondary_coin?) do
    if secondary_coin?, do: "Secondary coin", else: "Coin"
  end

  @spec unexpected_response_error(any(), any()) :: String.t()
  def unexpected_response_error(source, unexpected_response) do
    "Unexpected response from #{inspect(source)}: #{inspect(unexpected_response)}"
  end

  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
