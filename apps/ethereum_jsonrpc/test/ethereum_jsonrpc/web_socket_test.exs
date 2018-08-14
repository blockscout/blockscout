defmodule EthereumJSONRPC.WebSocketTest do
  use EthereumJSONRPC.WebSocket.Case, async: true

  import EthereumJSONRPC, only: [request: 1]

  alias EthereumJSONRPC.{Subscription, WebSocket}

  setup do
    %{block_interval: 5000}
  end

  describe "json_rpc/2" do
    test "can get result", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok, %{"number" => "0x0"}} =
               %{id: 1, method: "eth_getBlockByNumber", params: ["earliest", false]}
               |> request()
               |> WebSocket.json_rpc(json_rpc_named_arguments[:transport_options])
    end

    test "can get error", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      options = json_rpc_named_arguments[:transport_options]

      assert {:error,
              %{
                "code" => -32600,
                "message" => "Unsupported JSON-RPC protocol version"
              }} =
               %{id: 1, method: "eth_getBlockByNumber", params: ["earliest", false]}
               # purposely don't call `request()`, so that `jsonrpc` is NOT set.
               |> WebSocket.json_rpc(options)
    end
  end

  describe "subscribe/2" do
    test "can subscribe to newHeads", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      options = json_rpc_named_arguments[:transport_options]
      subscriber_pid = self()

      assert {:ok,
              %Subscription{
                id: subscription_id,
                subscriber_pid: ^subscriber_pid,
                transport: WebSocket,
                transport_options: ^options
              }} = WebSocket.subscribe("newHeads", [], options)

      assert is_binary(subscription_id)
    end

    test "delivers new heads to caller", %{
      block_interval: block_interval,
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      assert {:ok, subscription} = WebSocket.subscribe("newHeads", [], json_rpc_named_arguments[:transport_options])

      assert_receive {^subscription, {:ok, %{"number" => _}}}, block_interval * 2
    end
  end

  describe "unsubscribe/2" do
    test "can unsubscribe", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok, subscription} = WebSocket.subscribe("newHeads", [], json_rpc_named_arguments[:transport_options])

      assert {:ok, true} = WebSocket.unsubscribe(subscription)
    end

    test "stops messages being sent to subscriber", %{
      block_interval: block_interval,
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      assert {:ok, subscription} = WebSocket.subscribe("newHeads", [], json_rpc_named_arguments[:transport_options])

      wait = block_interval * 2

      assert_receive {^subscription, {:ok, %{"number" => _}}}, wait

      assert {:ok, true} = WebSocket.unsubscribe(subscription)

      clear_mailbox()

      refute_receive {^subscription, _}, wait
    end

    test "return error if already unsubscribed", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      assert {:ok, subscription} = WebSocket.subscribe("newHeads", [], json_rpc_named_arguments[:transport_options])
      assert {:ok, true} = WebSocket.unsubscribe(subscription)

      assert {:error, :not_found} = WebSocket.unsubscribe(subscription)
    end
  end

  defp clear_mailbox do
    receive do
      _ -> clear_mailbox()
    after
      0 ->
        :ok
    end
  end
end
