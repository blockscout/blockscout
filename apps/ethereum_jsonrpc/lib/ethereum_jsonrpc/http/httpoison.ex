defmodule EthereumJSONRPC.HTTP.HTTPoison do
  @moduledoc """
  Uses `HTTPoison` for `EthereumJSONRPC.HTTP`
  """

  alias EthereumJSONRPC.Celo.Telemetry
  alias EthereumJSONRPC.HTTP

  require UUID
  require Logger

  @behaviour HTTP

  @impl HTTP
  def json_rpc(url, json, options, method) when is_binary(url) and is_list(options) do
    start_time = Telemetry.start(:http_request, %{method: method})

    case HTTPoison.post(url, json, [{"Content-Type", "application/json"}], options) do
      {:ok, %HTTPoison.Response{body: body, status_code: status_code}} ->
        Telemetry.stop(:http_request, start_time, %{method: method, status_code: status_code})
        {:ok, %{body: body, status_code: status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Telemetry.event(:http_error, %{method: method, json: json}, %{reason: reason})

        if reason == :checkout_timeout do
          # https://github.com/edgurgel/httpoison/issues/414#issuecomment-693758760
          Logger.error("Restarting hackney pool after :checkout_timeout error")
          :hackney_pool.stop_pool(:ethereum_jsonrpc)
        end

        {:error, reason}
    end
  end

  def json_rpc(url, _json, _options, _method) when is_nil(url), do: {:error, "URL is nil"}
end
