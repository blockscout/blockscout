defmodule Explorer.ThirdPartyIntegrations.NovesFi do
  @moduledoc """
  Module for Noves.Fi API integration https://blockscout.noves.fi/swagger/index.html
  """

  require Logger

  alias Explorer.{Helper, HttpClient}
  alias Explorer.Utility.Microservice

  @recv_timeout 60_000

  @doc """
  Proxy request to Noves.fi API endpoints
  """
  @spec api_request(String.t(), Plug.Conn.t(), :get | :post_transactions) :: {any(), integer()}
  def api_request(url, conn, method \\ :get)

  def api_request(url, conn, :post_transactions) do
    headers = [{"apiKey", api_key()}, {"Content-Type", "application/json"}, {"accept", "text/plain"}]

    hashes =
      conn.query_params
      |> Map.get("hashes")
      |> (&if(is_map(&1),
            do: Map.values(&1),
            else: String.split(&1, ",")
          )).()

    prepared_params =
      conn.query_params
      |> Map.drop(["hashes"])

    case HttpClient.post(url, Jason.encode!(hashes), headers, recv_timeout: @recv_timeout, params: prepared_params) do
      {:ok, %{status_code: status, body: body}} ->
        {Helper.decode_json(body), status}

      {:error, reason} ->
        Logger.error(fn ->
          ["Error while requesting Noves.Fi API endpoint #{url}. The reason is: ", inspect(reason)]
        end)

        {nil, 500}
    end
  end

  def api_request(url, conn, :get) do
    headers = [{"apiKey", api_key()}]

    url_with_params = url <> "?" <> conn.query_string

    case HttpClient.get(url_with_params, headers, recv_timeout: @recv_timeout) do
      {:ok, %{status_code: status, body: body}} ->
        {Helper.decode_json(body), status}

      {:error, reason} ->
        Logger.error(fn ->
          ["Error while requesting Noves.Fi API endpoint #{url}. The reason is: ", inspect(reason)]
        end)

        {nil, 500}
    end
  end

  @doc """
  Noves.fi /evm/:chain/tx/:transaction_hash endpoint
  """
  @spec transaction_url(String.t()) :: String.t()
  def transaction_url(transaction_hash_string) do
    "#{base_url()}/evm/#{chain_name()}/tx/#{transaction_hash_string}"
  end

  @doc """
  Noves.fi /evm/:chain/describeTxs endpoint
  """
  @spec describe_transactions_url() :: String.t()
  def describe_transactions_url do
    "#{base_url()}/evm/#{chain_name()}/describeTxs"
  end

  @doc """
  Noves.fi /evm/:chain/txs/:address_hash endpoint
  """
  @spec address_transactions_url(String.t()) :: String.t()
  def address_transactions_url(address_hash_string) do
    "#{base_url()}/evm/#{chain_name()}/txs/#{address_hash_string}"
  end

  defp base_url do
    Microservice.base_url(__MODULE__)
  end

  defp chain_name do
    Application.get_env(:explorer, __MODULE__)[:chain_name]
  end

  defp api_key do
    Application.get_env(:explorer, __MODULE__)[:api_key]
  end
end
