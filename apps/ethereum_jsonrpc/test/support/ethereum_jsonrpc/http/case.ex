defmodule EthereumJSONRPC.HTTP.Case do
  use ExUnit.CaseTemplate

  import EthereumJSONRPC.Case, only: [module: 2]

  setup do
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.HTTP,
        transport_options: [
          http: http(),
          urls: [url()],
          http_options: http_options()
        ]
      ]
    }
  end

  def http do
    module("ETHEREUM_JSONRPC_HTTP", "EthereumJSONRPC.HTTP.Mox")
  end

  def http_options do
    [recv_timeout: 60_000, timeout: 60_000, pool: :ethereum_jsonrpc]
  end

  def url do
    "ETHEREUM_JSONRPC_HTTP_URL"
    |> System.get_env()
    |> Kernel.||("https://example.com")
  end
end
