defmodule Explorer.KnownTokens.Source do
  @moduledoc """
  Behaviour for fetching list of known tokens.
  """

  alias Explorer.Chain.Hash
  alias HTTPoison.{Error, Response}

  @doc """
  Fetches known tokens
  """
  @spec fetch_known_tokens() :: {:ok, [Hash.Address.t()]} | {:error, any}
  def fetch_known_tokens(source \\ known_tokens_source()) do
    case HTTPoison.get(source.source_url(), headers()) do
      {:ok, %Response{body: body, status_code: 200}} ->
        {:ok, decode_json(body)}

      {:ok, %Response{body: body, status_code: status_code}} when status_code in 400..499 ->
        {:error, decode_json(body)["error"]}

      {:ok, %Response{body: _body, status_code: status_code}} when status_code in 301..302 ->
        {:error, "CoinGecko redirected"}

      {:ok, %Response{body: _body, status_code: _status_code}} ->
        {:error, "CoinGecko unexpected status code"}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Url for querying the list of known tokens.
  """
  @callback source_url() :: String.t()

  def headers do
    [{"Content-Type", "application/json"}]
  end

  def decode_json(data) do
    Jason.decode!(data)
  end

  @spec known_tokens_source() :: module()
  defp known_tokens_source do
    config(:source) || Explorer.KnownTokens.Source.MyEtherWallet
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end
end
