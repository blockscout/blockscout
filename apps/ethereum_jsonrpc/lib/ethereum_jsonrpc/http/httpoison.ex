# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.HTTP.HTTPoison do
  @moduledoc """
  Uses `HTTPoison` for `EthereumJSONRPC.HTTP`
  """

  alias EthereumJSONRPC.HTTP
  alias EthereumJSONRPC.HTTP.Helper
  alias EthereumJSONRPC.Prometheus.Instrumenter
  alias Utils.HttpClient.HTTPoisonHelper

  @behaviour HTTP

  @impl HTTP
  def json_rpc(url, json, headers, options) when is_binary(url) and is_list(options) do
    requests = Helper.decode_requests(json)
    method = requests |> List.first(%{}) |> Map.get("method")
    l1? = Keyword.get(options, :layer) == :l1

    Instrumenter.json_rpc_requests(method, l1?)
    Helper.track_json_rpc_calls(requests, l1?)
    Helper.track_eth_call_methods(requests, l1?)

    case HTTPoison.post(url, json, headers, HTTPoisonHelper.request_opts(options)) do
      {:ok, %HTTPoison.Response{body: body, status_code: status_code, headers: headers}} ->
        with {:ok, decoded_body} <- Jason.decode(body),
             true <- Helper.response_body_has_error?(decoded_body) do
          Instrumenter.json_rpc_errors(method, l1?)
        end

        {:ok, %{body: Helper.try_unzip(body, headers), status_code: status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Instrumenter.json_rpc_errors(method, l1?)

        {:error, reason}
    end
  end

  def json_rpc(url, _json, _headers, _options) when is_nil(url), do: {:error, "URL is nil"}
end
