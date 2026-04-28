defmodule Explorer.EthRPCTest do
  use Explorer.DataCase, async: false

  import Mox

  alias Explorer.EthRPC

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    original_json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    original_eth_rpc_config = Application.get_env(:explorer, Explorer.EthRPC)

    Application.put_env(:explorer, :json_rpc_named_arguments,
      transport: EthereumJSONRPC.Mox,
      transport_options: []
    )

    on_exit(fn ->
      restore_env(:explorer, :json_rpc_named_arguments, original_json_rpc_named_arguments)
      restore_env(:explorer, Explorer.EthRPC, original_eth_rpc_config)
    end)

    :ok
  end

  test "extended proxy methods are disabled by default" do
    request = %{"id" => 1, "jsonrpc" => "2.0", "method" => "net_version", "params" => []}

    assert [response] = EthRPC.responses([request])
    assert response == %{error: %{code: -32601, message: "Method not found."}, id: 1}
  end

  test "extended proxy methods are proxied when feature flag is enabled" do
    set_extended_proxy_methods_enabled(true)

    expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: 1, jsonrpc: "2.0", method: "net_version", params: []}], _options ->
      {:ok, [%{id: 1, jsonrpc: "2.0", result: "1"}]}
    end)

    request = %{"id" => 1, "jsonrpc" => "2.0", "method" => "net_version", "params" => []}

    assert [response] = EthRPC.responses([request])
    assert response == %{id: 1, result: "1"}
  end

  test "default proxy methods remain available when feature flag is disabled" do
    set_extended_proxy_methods_enabled(false)

    expect(EthereumJSONRPC.Mox, :json_rpc, fn
      [%{id: 1, jsonrpc: "2.0", method: "eth_getCode", params: [_, "latest"]}], _options ->
        {:ok, [%{id: 1, jsonrpc: "2.0", result: "0x"}]}
    end)

    request = %{
      "id" => 1,
      "jsonrpc" => "2.0",
      "method" => "eth_getCode",
      "params" => ["0x0000000000000000000000000000000000000007", "latest"]
    }

    assert [response] = EthRPC.responses([request])
    assert response == %{id: 1, result: "0x"}
  end

  test "eth_feeHistory accepts both arity 2 and arity 3" do
    set_extended_proxy_methods_enabled(true)

    expect(EthereumJSONRPC.Mox, :json_rpc, fn
      [
        %{id: 1, jsonrpc: "2.0", method: "eth_feeHistory", params: ["0x4", "latest"]},
        %{id: 2, jsonrpc: "2.0", method: "eth_feeHistory", params: ["0x4", "latest", [25, 50]]}
      ],
      _options ->
        {:ok,
         [
           %{id: 1, jsonrpc: "2.0", result: %{oldestBlock: "0x1"}},
           %{id: 2, jsonrpc: "2.0", result: %{oldestBlock: "0x1"}}
         ]}
    end)

    requests = [
      %{"id" => 1, "jsonrpc" => "2.0", "method" => "eth_feeHistory", "params" => ["0x4", "latest"]},
      %{"id" => 2, "jsonrpc" => "2.0", "method" => "eth_feeHistory", "params" => ["0x4", "latest", [25, 50]]}
    ]

    assert [%{id: 1, result: %{oldestBlock: "0x1"}}, %{id: 2, result: %{oldestBlock: "0x1"}}] =
             EthRPC.responses(requests)
  end

  defp set_extended_proxy_methods_enabled(value) do
    Application.put_env(:explorer, Explorer.EthRPC, extended_proxy_methods_enabled: value)
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
