defmodule EthereumJSONRPC.HTTP.Mint do
  @moduledoc """
  Uses `Tesla.Mint` for `EthereumJSONRPC.HTTP`
  """

  alias EthereumJSONRPC.HTTP
  alias EthereumJSONRPC.HTTP.Helper
  alias EthereumJSONRPC.Prometheus.Instrumenter

  @behaviour HTTP

  @impl HTTP
  def json_rpc(url, json, headers, options) when is_binary(url) and is_list(options) do
    method = Helper.get_method_from_json_string(json)

    Instrumenter.json_rpc_requests(method)

    case Tesla.post(client(options), url, json, headers: headers, opts: request_opts(options)) do
      {:ok, %Tesla.Env{body: body, status: status_code, headers: headers}} ->
        with {:ok, decoded_body} <- Jason.decode(body),
             true <- Helper.response_body_has_error?(decoded_body) do
          Instrumenter.json_rpc_errors(method)
        end

        {:ok, %{body: Helper.try_unzip(body, headers), status_code: status_code}}

      {:error, error} ->
        Instrumenter.json_rpc_errors(method)

        {:error, error}
    end
  end

  def json_rpc(url, _json, _headers, _options) when is_nil(url), do: {:error, "URL is nil"}

  defp client(options) do
    Tesla.client([{Tesla.Middleware.Timeout, timeout: options[:recv_timeout]}], Tesla.Adapter.Mint)
  end

  defp request_opts(options) do
    [adapter: [protocols: [:http1], timeout: options[:recv_timeout], transport_opts: [timeout: options[:timeout]]]]
  end
end
