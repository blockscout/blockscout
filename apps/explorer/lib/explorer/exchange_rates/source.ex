defmodule Explorer.ExchangeRates.Source do
  @moduledoc """
  Behaviour for fetching exchange rates from external sources.
  """

  alias Explorer.Chain.Hash
  alias Explorer.ExchangeRates.Source.{CoinGecko, Cryptorank}
  alias Explorer.ExchangeRates.Token
  alias Explorer.Helper
  alias HTTPoison.{Error, Response}

  @doc """
  Fetches exchange rates for currencies/tokens.
  """
  @spec fetch_exchange_rates(module) :: {:ok, [Token.t()]} | {:error, any}
  def fetch_exchange_rates(source \\ exchange_rates_source()) do
    source_url = source.source_url()
    fetch_exchange_rates_request(source, source_url, source.headers())
  end

  @doc """
  Fetches exchange rates for secondary coin.
  """
  @spec fetch_secondary_exchange_rates(module) :: {:ok, [Token.t()]} | {:error, any}
  def fetch_secondary_exchange_rates(source \\ secondary_exchange_rates_source()) do
    case source.secondary_source_url() do
      :ignore -> {:error, "Secondary coin fetching is not implemented for source #{inspect(source)}"}
      source_url -> fetch_exchange_rates_request(source, source_url, source.headers())
    end
  end

  @spec fetch_exchange_rates_for_token(String.t()) :: {:ok, [Token.t()]} | {:error, any}
  def fetch_exchange_rates_for_token(symbol) do
    source_url = CoinGecko.source_url(symbol)
    headers = CoinGecko.headers()
    fetch_exchange_rates_request(CoinGecko, source_url, headers)
  end

  @spec fetch_exchange_rates_for_token_address(String.t()) :: {:ok, [Token.t()]} | {:error, any}
  def fetch_exchange_rates_for_token_address(address_hash) do
    source_url = CoinGecko.source_url(address_hash)
    headers = CoinGecko.headers()
    fetch_exchange_rates_request(CoinGecko, source_url, headers)
  end

  @spec fetch_market_data_for_token_addresses([Hash.Address.t()]) ::
          {:ok, %{Hash.Address.t() => %{fiat_value: float() | nil, circulating_market_cap: float() | nil}}}
          | {:error, any}
  def fetch_market_data_for_token_addresses(address_hashes, source \\ exchange_rates_source()) do
    source_url = source.source_url(address_hashes)
    fetch_exchange_rates_request(source, source_url, source.headers())
  end

  @spec fetch_token_hashes_with_market_data :: {:ok, [String.t()]} | {:error, any}
  def fetch_token_hashes_with_market_data do
    source_url = CoinGecko.source_url(:coins_list)
    headers = CoinGecko.headers()

    case http_request(source_url, headers) do
      {:ok, result} ->
        {:ok,
         result
         |> CoinGecko.format_data()}

      resp ->
        resp
    end
  end

  @doc """
  Fetches exchange rates for tokens from cryptorank.
  """
  @spec cryptorank_fetch_currencies(integer(), integer()) ::
          {:error, any()}
          | {:ok, map()}
  def cryptorank_fetch_currencies(limit, offset) do
    source_url = Cryptorank.source_url(:currencies, limit, offset)

    case http_request(source_url, []) do
      {:ok, result} ->
        {:ok,
         result
         |> Cryptorank.format_data()}

      resp ->
        resp
    end
  end

  defp fetch_exchange_rates_request(_source, source_url, _headers) when is_nil(source_url),
    do: {:error, "Source URL is nil"}

  defp fetch_exchange_rates_request(source, source_url, headers) do
    case http_request(source_url, headers) do
      {:ok, result} when is_map(result) ->
        result_formatted =
          result
          |> source.format_data()

        {:ok, result_formatted}

      resp ->
        resp
    end
  end

  @doc """
  Callback for api's to format the data returned by their query.
  """
  @callback format_data(map() | list()) :: [any]

  @doc """
  Url for the api to query to get the market info.
  """
  @callback source_url :: String.t()

  @callback source_url(String.t()) :: String.t() | :ignore

  @doc """
  Url for the api to query to get the market info for secondary coin.
  """
  @callback secondary_source_url :: String.t() | nil | :ignore

  @callback headers :: [any]

  def headers do
    [{"Content-Type", "application/json"}]
  end

  def to_decimal(nil), do: nil

  def to_decimal(%Decimal{} = value), do: value

  def to_decimal(value) when is_float(value) do
    Decimal.from_float(value)
  end

  def to_decimal(value) when is_integer(value) or is_binary(value) do
    Decimal.new(value)
  end

  @spec exchange_rates_source() :: module()
  defp exchange_rates_source do
    config(:source) || Explorer.ExchangeRates.Source.CoinGecko
  end

  @spec secondary_exchange_rates_source() :: module()
  defp secondary_exchange_rates_source do
    config(:secondary_coin_source) || exchange_rates_source()
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  def http_request(source_url, additional_headers) do
    case HTTPoison.get(source_url, headers() ++ additional_headers) do
      {:ok, %Response{body: body, status_code: 200}} ->
        parse_http_success_response(body)

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..526 ->
        parse_http_error_response(body, status_code)

      {:ok, %Response{status_code: status_code}} when status_code in 300..308 ->
        {:error, "Source redirected"}

      {:ok, %Response{status_code: _status_code}} ->
        {:error, "Source unexpected status code"}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp parse_http_success_response(body) do
    body_json = Helper.decode_json(body)

    {:ok, body_json}
  end

  defp parse_http_error_response(body, status_code) do
    body_json = Helper.decode_json(body)

    if is_map(body_json) do
      {:error, "#{status_code}: #{body_json["error"]}"}
    else
      {:error, "#{status_code}: #{body}"}
    end
  end

  @doc """
  Returns `nil` if the date is `nil`, otherwise returns the parsed date.
  Date should be in ISO8601 format
  """
  @spec maybe_get_date(String.t() | nil) :: DateTime.t() | nil
  def maybe_get_date(nil), do: nil

  def maybe_get_date(date) do
    {:ok, parsed_date, 0} = DateTime.from_iso8601(date)
    parsed_date
  end

  @doc """
  Returns `nil` if the url is invalid, otherwise returns the parsed url.
  """
  @spec handle_image_url(String.t() | nil) :: String.t() | nil
  def handle_image_url(url) do
    case Helper.validate_url(url) do
      {:ok, url} -> url
      _ -> nil
    end
  end
end
