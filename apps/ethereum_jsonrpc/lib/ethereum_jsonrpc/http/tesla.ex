defmodule EthereumJSONRPC.HTTP.Tesla do
  @moduledoc """
  Uses `Tesla.Mint` for `EthereumJSONRPC.HTTP`
  """

  alias EthereumJSONRPC.HTTP
  alias EthereumJSONRPC.HTTP.Helper
  alias EthereumJSONRPC.Prometheus.Instrumenter
  alias Utils.HttpClient.TeslaHelper

  @behaviour HTTP

  @impl HTTP
  def json_rpc(url, json, headers, options) when is_binary(url) and is_list(options) do
    method = Helper.get_method_from_json_string(json)
    request_compression_enabled? = Helper.request_compression_enabled?(method)
    client = TeslaHelper.client(options, compression_middleware(request_compression_enabled?))

    Instrumenter.json_rpc_requests(method)

    case Tesla.post(client, url, json, headers: headers, opts: TeslaHelper.request_opts(options)) do
      {:ok, %Tesla.Env{body: body, status: status_code, headers: headers}} ->
        with {:ok, decoded_body} <- Jason.decode(body),
             true <- Helper.response_body_has_error?(decoded_body) do
          Instrumenter.json_rpc_errors(method)
        end

        response_body = if request_compression_enabled?, do: body, else: Helper.try_unzip(body, headers)

        {:ok, %{body: response_body, status_code: status_code}}

      {:error, error} ->
        Instrumenter.json_rpc_errors(method)

        {:error, error}
    end
  end

  def json_rpc(url, _json, _headers, _options) when is_nil(url), do: {:error, "URL is nil"}

  defp compression_middleware(true), do: [{Tesla.Middleware.Compression, format: "gzip"}]
  defp compression_middleware(false), do: []
end
