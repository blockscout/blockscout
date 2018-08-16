defmodule EthereumJSONRPC.WebSocketTest do
  use EthereumJSONRPC.WebSocket.Case, async: true

  import EthereumJSONRPC, only: [request: 1]
  import Mox

  alias EthereumJSONRPC.{Subscription, WebSocket}

  setup :verify_on_exit!

  describe "json_rpc/2" do
    test "can get result", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport_options = subscribe_named_arguments[:transport_options]

      if transport_options[:web_socket] == EthereumJSONRPC.WebSocket.Mox do
        expect(EthereumJSONRPC.WebSocket.Mox, :json_rpc, fn _, _ ->
          {:ok, %{"number" => "0x0"}}
        end)
      end

      assert {:ok, %{"number" => "0x0"}} =
               %{id: 1, method: "eth_getBlockByNumber", params: ["earliest", false]}
               |> request()
               |> WebSocket.json_rpc(transport_options)
    end

    test "can get error", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport_options = subscribe_named_arguments[:transport_options]

      if transport_options[:web_socket] == EthereumJSONRPC.WebSocket.Mox do
        expect(EthereumJSONRPC.WebSocket.Mox, :json_rpc, fn _, _ ->
          {:error,
           %{
             "code" => -32600,
             "message" => "Unsupported JSON-RPC protocol version"
           }}
        end)
      end

      assert {:error,
              %{
                "code" => -32600,
                "message" => "Unsupported JSON-RPC protocol version"
              }} =
               %{id: 1, method: "eth_getBlockByNumber", params: ["earliest", false]}
               # purposely don't call `request()`, so that `jsonrpc` is NOT set.
               |> WebSocket.json_rpc(transport_options)
    end
  end

  describe "subscribe/2" do
    test "can subscribe to newHeads", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if transport_options[:web_socket] == EthereumJSONRPC.WebSocket.Mox do
        expect(EthereumJSONRPC.WebSocket.Mox, :subscribe, fn _, _, _ ->
          {:ok,
           %Subscription{
             id: "0x1",
             subscriber_pid: subscriber_pid,
             transport: transport,
             transport_options: transport_options
           }}
        end)
      end

      assert {:ok,
              %Subscription{
                id: subscription_id,
                subscriber_pid: ^subscriber_pid,
                transport: ^transport,
                transport_options: ^transport_options
              }} = WebSocket.subscribe("newHeads", [], transport_options)

      assert is_binary(subscription_id)
    end

    test "delivers new heads to caller", %{
      block_interval: block_interval,
      subscribe_named_arguments: subscribe_named_arguments
    } do
      transport_options = subscribe_named_arguments[:transport_options]
      web_socket_module = Keyword.fetch!(transport_options, :web_socket)
      subscriber_pid = self()

      if web_socket_module == EthereumJSONRPC.WebSocket.Mox do
        expect(web_socket_module, :subscribe, fn _, _, _ ->
          subscription = %Subscription{
            id: "0x1",
            subscriber_pid: subscriber_pid,
            transport: Keyword.fetch!(subscribe_named_arguments, :transport),
            transport_options: transport_options
          }

          Process.send_after(subscriber_pid, {subscription, {:ok, %{"number" => "0x1"}}}, block_interval)

          {:ok, subscription}
        end)
      end

      assert {:ok, subscription} = WebSocket.subscribe("newHeads", [], transport_options)

      assert_receive {^subscription, {:ok, %{"number" => _}}}, block_interval * 2
    end
  end

  describe "unsubscribe/2" do
    test "can unsubscribe", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport_options = subscribe_named_arguments[:transport_options]
      web_socket_module = Keyword.fetch!(transport_options, :web_socket)
      subscriber_pid = self()

      if web_socket_module == EthereumJSONRPC.WebSocket.Mox do
        subscription = %Subscription{
          id: "0x1",
          subscriber_pid: subscriber_pid,
          transport: Keyword.fetch!(subscribe_named_arguments, :transport),
          transport_options: transport_options
        }

        web_socket_module
        |> expect(:subscribe, fn _, _, _ -> {:ok, subscription} end)
        |> expect(:unsubscribe, fn _, ^subscription -> :ok end)
      end

      assert {:ok, subscription} = WebSocket.subscribe("newHeads", [], transport_options)

      assert :ok = WebSocket.unsubscribe(subscription)
    end

    test "stops messages being sent to subscriber", %{
      block_interval: block_interval,
      subscribe_named_arguments: subscribe_named_arguments
    } do
      transport_options = subscribe_named_arguments[:transport_options]
      web_socket_module = Keyword.fetch!(transport_options, :web_socket)
      subscriber_pid = self()

      if web_socket_module == EthereumJSONRPC.WebSocket.Mox do
        subscription = %Subscription{
          id: "0x1",
          subscriber_pid: subscriber_pid,
          transport: Keyword.fetch!(subscribe_named_arguments, :transport),
          transport_options: transport_options
        }

        web_socket_module
        |> expect(:subscribe, fn pid, _, _ when is_pid(pid) ->
          send(pid, {:subscribe, subscription})

          {:ok, subscription}
        end)
        |> expect(:unsubscribe, fn pid, ^subscription when is_pid(pid) ->
          send(pid, {:unsubscribe, subscription})

          :ok
        end)
      end

      assert {:ok, subscription} = WebSocket.subscribe("newHeads", [], subscribe_named_arguments[:transport_options])

      wait = block_interval * 2

      assert_receive {^subscription, {:ok, %{"number" => _}}}, wait

      assert :ok = WebSocket.unsubscribe(subscription)

      clear_mailbox()

      refute_receive {^subscription, _}, wait
    end

    test "return error if already unsubscribed", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport_options = subscribe_named_arguments[:transport_options]
      web_socket_module = Keyword.fetch!(transport_options, :web_socket)
      subscriber_pid = self()

      if web_socket_module == EthereumJSONRPC.WebSocket.Mox do
        subscription = %Subscription{
          id: "0x1",
          subscriber_pid: subscriber_pid,
          transport: Keyword.fetch!(subscribe_named_arguments, :transport),
          transport_options: transport_options
        }

        web_socket_module
        |> expect(:subscribe, fn _, _, _ -> {:ok, subscription} end)
        |> expect(:unsubscribe, fn _, ^subscription -> :ok end)
        |> expect(:unsubscribe, fn _, ^subscription -> {:error, :not_found} end)
      end

      assert {:ok, subscription} = WebSocket.subscribe("newHeads", [], transport_options)
      assert :ok = WebSocket.unsubscribe(subscription)

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
