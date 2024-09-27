defmodule Indexer.Fetcher.Filecoin.BeryxAPI do
  @moduledoc """
  Interacts with the Beryx API to fetch account information based on an Ethereum
  address hash
  """

  alias Explorer.Helper
  alias HTTPoison.Response

  @doc """
  Fetches account information for a given Ethereum address hash from the Beryx API.

  ## Parameters
  - `eth_address_hash` - The Ethereum address hash to fetch information for.

  ## Returns
  - `{:ok, map()}`: On success, returns the account information as a map.
  - `{:error, integer(), map()}`: On failure, returns the HTTP status code and the error message as a map.
  - `{:error, HTTPoison.Error.t()}`: On network or other HTTP errors, returns the error structure.
  """
  @spec fetch_account_info(EthereumJSONRPC.address()) ::
          {:ok, map()}
          | {:error, integer(), map()}
          | {:error, HTTPoison.Error.t()}
  def fetch_account_info(eth_address_hash) do
    config = Application.get_env(:indexer, __MODULE__)
    base_url = config |> Keyword.get(:base_url) |> String.trim_trailing("/")
    api_token = config[:api_token]

    url = "#{base_url}/account/info/#{eth_address_hash}"

    headers = [
      {"Authorization", "Bearer #{api_token}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %Response{body: body, status_code: 200}} ->
        json = Helper.decode_json(body)
        {:ok, json}

      {:ok, %Response{body: body, status_code: status_code}} ->
        json = Helper.decode_json(body)
        {:error, status_code, json}

      {:error, %HTTPoison.Error{}} = error ->
        error
    end
  end
end
