defmodule Explorer.ThirdPartyIntegrations.Xname do
  @moduledoc """
  Module for proxying xname https://xname.app/ API endpoints
  """

  require Logger

  alias Explorer.{Helper, HttpClient}
  alias Explorer.Utility.Microservice

  @recv_timeout 60_000

  @doc """
  Proxy request to XName API endpoints
  """
  @spec api_request(String.t(), Plug.Conn.t(), atom()) :: {any(), integer()}
  def api_request(url, conn, method \\ :get)

  def api_request(url, _conn, :get) do
    headers = [{"x-api-key", api_key()}]

    case HttpClient.get(url, headers, recv_timeout: @recv_timeout) do
      {:ok, %{status_code: status, body: body}} ->
        {Helper.decode_json(body), status}

      {:error, reason} ->
        Logger.error(fn ->
          ["Error while requesting XName app API endpoint #{url}. The reason is: ", inspect(reason)]
        end)

        {nil, 500}
    end
  end

  @doc """
  https://gateway.xname.app/xhs/level/:address_hash endpoint
  """
  @spec address_url(String.t()) :: String.t()
  def address_url(address_hash_string) do
    "#{base_url()}/xhs/level/#{address_hash_string}"
  end

  defp base_url do
    Microservice.base_url(__MODULE__)
  end

  defp api_key do
    Application.get_env(:explorer, __MODULE__)[:api_key]
  end
end
