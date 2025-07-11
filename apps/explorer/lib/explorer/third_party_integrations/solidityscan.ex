defmodule Explorer.ThirdPartyIntegrations.SolidityScan do
  @moduledoc """
  Module for SolidityScan integration https://apidoc.solidityscan.com/solidityscan-security-api/solidityscan-other-apis/quickscan-api-v1
  """

  require Logger
  alias Explorer.{Helper, HttpClient}

  @recv_timeout 60_000

  @doc """
  Proxy request to solidityscan API endpoint for the given smart-contract
  """
  @spec solidityscan_request(String.t()) :: any()
  def solidityscan_request(address_hash_string) do
    headers = [{"Authorization", "Token #{api_key()}"}]

    url = base_url(address_hash_string)

    if url do
      case HttpClient.get(url, headers, recv_timeout: @recv_timeout) do
        {:ok, %{status_code: 200, body: body}} ->
          Helper.decode_json(body)

        _ ->
          nil
      end
    else
      Logger.warning(
        "SOLIDITYSCAN_CHAIN_ID or SOLIDITYSCAN_API_TOKEN env variable is not configured on the backend. Please, set it."
      )

      nil
    end
  end

  defp base_url(address_hash_string) do
    if chain_id() && api_key() do
      "https://api.solidityscan.com/api/v1/quickscan/#{platform_id()}/#{chain_id()}/#{address_hash_string}"
    else
      nil
    end
  end

  defp platform_id do
    Application.get_env(:explorer, __MODULE__)[:platform_id]
  end

  defp chain_id do
    Application.get_env(:explorer, __MODULE__)[:chain_id]
  end

  defp api_key do
    Application.get_env(:explorer, __MODULE__)[:api_key]
  end
end
