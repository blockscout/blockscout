# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.MicroserviceInterfaces.ContractsInfo do
  @moduledoc """
    Interface to interact with Blockscout Contracts Info microservice
  """

  alias Explorer.MicroserviceInterfaces.HttpClient
  alias Explorer.Utility.Microservice

  require Logger

  @request_error_msg "Error while sending request to Contracts Info microservice"

  @doc """
    Request for DEX pools matching the pool ID via GET {{baseUrl}}/api/v1/chains/:chain_id/pools?query=:pool_id.
    The lookup is served from the microservice DB only, so it does not wait for pool data to be refreshed.
  """
  @spec get_pools_by_id(binary()) :: {:ok, [map()]} | {:error, :disabled | binary() | Exception.t()}
  def get_pools_by_id(pool_id) do
    with :ok <- Microservice.check_enabled(__MODULE__) do
      pools_url()
      |> http_get_request(%{"query" => pool_id})
      |> case do
        {:ok, %{"items" => pools}} when is_list(pools) ->
          {:ok, pools}

        {:ok, unexpected} ->
          log_error(pools_url(), {:unexpected_body, unexpected})
          {:error, @request_error_msg}

        error ->
          error
      end
    end
  end

  defp http_get_request(url, query_params) do
    case HttpClient.get(url, [], params: query_params) do
      {:ok, %{body: body, status_code: 200}} ->
        Utils.JSON.decode(body)

      {_, error} ->
        log_error(url, error)
        {:error, @request_error_msg}
    end
  end

  defp log_error(url, error) do
    Logger.error(fn ->
      [
        "#{@request_error_msg} url: #{url}: ",
        inspect(error)
      ]
    end)
  end

  defp pools_url do
    "#{base_url()}/chains/#{chain_specifier()}/pools"
  end

  defp base_url do
    "#{Microservice.base_url(__MODULE__)}/api/v1"
  end

  # Either just `chain_id` or `chain_id:instance_id`, defaults to `chain_id`
  defp chain_specifier do
    Application.get_env(:explorer, __MODULE__)[:chain_specifier] || Application.get_env(:block_scout_web, :chain_id)
  end
end
