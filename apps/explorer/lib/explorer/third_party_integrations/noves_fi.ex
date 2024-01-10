defmodule Explorer.ThirdPartyIntegrations.NovesFi do
  @moduledoc """
  Module for Noves.Fi API integration https://blockscout.noves.fi/swagger/index.html
  """

  alias Explorer.Helper
  alias Explorer.Utility.Microservice

  @recv_timeout 60_000

  @doc """
  Proxy request to noves.fi API endpoints
  """
  @spec noves_fi_api_request(String.t(), Plug.Conn.t()) :: {any(), integer()}
  def noves_fi_api_request(url, conn) do
    headers = [{"apiKey", api_key()}]
    url_with_params = url <> "?" <> conn.query_string

    case HTTPoison.get(url_with_params, headers, recv_timeout: @recv_timeout) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {Helper.decode_json(body), status}

      _ ->
        {nil, 500}
    end
  end

  @doc """
  Noves.fi /evm/{chain}/tx/{txHash} endpoint
  """
  @spec tx_url(String.t()) :: String.t()
  def tx_url(transaction_hash_string) do
    "#{base_url()}/evm/#{chain_name()}/tx/#{transaction_hash_string}"
  end

  @doc """
  Noves.fi /evm/{chain}/describeTx/{txHash} endpoint
  """
  @spec describe_tx_url(String.t()) :: String.t()
  def describe_tx_url(transaction_hash_string) do
    "#{base_url()}/evm/#{chain_name()}/describeTx/#{transaction_hash_string}"
  end

  @doc """
  Noves.fi /evm/{chain}/txs/{accountAddress} endpoint
  """
  @spec address_txs_url(String.t()) :: String.t()
  def address_txs_url(address_hash_string) do
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
