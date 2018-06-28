defmodule EthereumJSONRPC.GethTest do
  use ExUnit.Case, async: false

  alias EthereumJSONRPC.Geth

  @moduletag :no_parity

  setup do
    {variant, url} =
      case System.get_env("ETHEREUM_JSONRPC_VARIANT") || "parity" do
        "geth" ->
          {EthereumJSONRPC.Geth, "https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY"}

        "parity" ->
          {EthereumJSONRPC.Parity, "https://sokol-trace.poa.network"}

        variant_name ->
          raise ArgumentError, "Unsupported variant name (#{variant_name})"
      end

    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.HTTP,
        transport_options: [
          http: EthereumJSONRPC.HTTP.HTTPoison,
          url: url,
          http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
        ]
      ],
      variant: variant
    }
  end

  describe "fetch_internal_transactions/2" do
    test "is not supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      Geth.fetch_internal_transactions(
        [
          "0x2ec382949ba0b22443aa4cb38267b1fb5e68e188109ac11f7a82f67571a0adf3"
        ],
        json_rpc_named_arguments
      )
    end
  end

  describe "fetch_pending_transactions/1" do
    test "is not supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      EthereumJSONRPC.Geth.fetch_pending_transactions(json_rpc_named_arguments)
    end
  end
end
