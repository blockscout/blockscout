defmodule Explorer.ThirdPartyIntegrations.Zerion do
  @moduledoc """
  Module for Zerion API integration https://developers.zerion.io/reference
  """

  require Logger

  alias Explorer.Helper
  alias Explorer.Utility.Microservice

  @recv_timeout 60_000

  @doc """
  Proxy request to Zerion API endpoints
  """
  @spec api_request(String.t(), Plug.Conn.t(), atom()) :: {any(), integer()}
  def api_request(url, conn, method \\ :get)

  def api_request(url, _conn, :get) do
    auth_token = Base.encode64("#{api_key()}:")
    headers = [{"Authorization", "Basic #{auth_token}"}]

    case HTTPoison.get(url, headers, recv_timeout: @recv_timeout) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {Helper.decode_json(body), status}

      {:error, reason} ->
        Logger.error(fn ->
          ["Error while requesting Zerion API endpoint #{url}. The reason is: ", inspect(reason)]
        end)

        {nil, 500}
    end
  end

  @doc """
  Zerion /wallets/:address_hash/portfolio endpoint
  """
  @spec wallet_portfolio_url(String.t()) :: String.t()
  def wallet_portfolio_url(address_hash_string) do
    "#{base_url()}/wallets/#{address_hash_string}/portfolio"
  end

  defp base_url do
    Microservice.base_url(__MODULE__)
  end

  defp api_key do
    Application.get_env(:explorer, __MODULE__)[:api_key]
  end
end
