defmodule Explorer.ThirdPartyIntegrations.SolidityScan do
  @moduledoc """
  Module for SolidityScan integration https://apidoc.solidityscan.com/solidityscan-security-api/solidityscan-other-apis/quickscan-api-v1
  """

  alias Explorer.Helper

  @blockscout_platform_id "16"
  @recv_timeout 60_000

  @doc """
  Proxy request to solidityscan API endpoint for the given smart-contract
  """
  @spec solidityscan_request(String.t()) :: any()
  def solidityscan_request(address_hash_string) do
    headers = [{"Authorization", "Token #{api_key()}"}]

    url = base_url(address_hash_string)

    case HTTPoison.get(url, headers, recv_timeout: @recv_timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Helper.decode_json(body)

      _ ->
        nil
    end
  end

  defp base_url(address_hash_string) do
    "https://api.solidityscan.com/api/v1/quickscan/#{@blockscout_platform_id}/#{chain_id()}/#{address_hash_string}"
  end

  defp chain_id do
    Application.get_env(:explorer, __MODULE__)[:chain_id]
  end

  defp api_key do
    Application.get_env(:explorer, __MODULE__)[:api_key]
  end
end
