defmodule Explorer.ExchangeRates.Source do
  @moduledoc """
  Behaviour for fetching exchange rates from external sources.
  """
  alias Explorer.ExchangeRates.{Source, Token}
  alias HTTPoison.{Error, Response}

  @doc """
  Fetches exchange rates for currencies/tokens.
  """
  @spec fetch_exchange_rates(module) :: {:ok, [Token.t()]} | {:error, any}
  def fetch_exchange_rates(source \\ exchange_rates_source()) do
    source_url = source.source_url()
    fetch_exchange_rates_request(source, source_url)
  end

  @spec fetch_exchange_rates_for_token(String.t()) :: {:ok, [Token.t()]} | {:error, any}
  def fetch_exchange_rates_for_token(symbol) do
    source_url = Source.CoinGecko.source_url(symbol)
    fetch_exchange_rates_request(Source.CoinGecko, source_url)
  end

  defp fetch_exchange_rates_request(_source, source_url) when is_nil(source_url), do: {:error, "Source URL is nil"}

  defp fetch_exchange_rates_request(source, source_url) do
    case HTTPoison.get(source_url, headers()) do
      {:ok, %Response{body: body, status_code: 200}} ->
        result =
          body
          |> decode_json()
          |> source.format_data()

        {:ok, result}

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..499 ->
        if is_map(decode_json(body)) do
          {:error, decode_json(body)["error"]}
        else
          {:error, body}
        end

      {:error, %Error{reason: reason}} ->
        {:error, reason}

      {:error, :nxdomain} ->
        {:error, "CoinGecko is not responsive"}
    end
  end

  @doc """
  Callback for api's to format the data returned by their query.
  """
  @callback format_data(String.t()) :: [any]

  @doc """
  Url for the api to query to get the market info.
  """
  @callback source_url :: String.t()

  @callback source_url(String.t()) :: String.t() | :ignore

  def headers do
    [{"Content-Type", "application/json"}]
  end

  def decode_json(data) do
    Jason.decode!(data)
  rescue
    _ -> data
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

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
