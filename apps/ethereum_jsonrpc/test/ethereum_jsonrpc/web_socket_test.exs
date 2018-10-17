defmodule EthereumJSONRPC.WebSocketTest do
  use EthereumJSONRPC.WebSocket.Case, async: true

  import EthereumJSONRPC, only: [request: 1]
  import Mox

  alias EthereumJSONRPC.{Subscription, WebSocket}
  alias EthereumJSONRPC.WebSocket.WebSocketClient

  setup :verify_on_exit!

  describe "json_rpc/2" do
    test "can get result", %{subscribe_named_arguments: subscribe_named_arguments} do
      %WebSocket{web_socket: web_socket} = transport_options = subscribe_named_arguments[:transport_options]

      if web_socket == EthereumJSONRPC.WebSocket.Mox do
        expect(EthereumJSONRPC.WebSocket.Mox, :json_rpc, fn _, _ ->
          {:ok, %{"number" => "0x0"}}
        end)
      end

      assert {:ok, %{"number" => "0x0"}} =
               %{id: 1, method: "eth_getBlockByNumber", params: ["earliest", false]}
               |> request()
               |> WebSocket.json_rpc(transport_options)
    end

    # Infura timeouts on 2018-09-10
    @tag :no_geth
    test "can get error", %{subscribe_named_arguments: subscribe_named_arguments} do
      %WebSocket{web_socket: web_socket} = transport_options = subscribe_named_arguments[:transport_options]

      if web_socket == EthereumJSONRPC.WebSocket.Mox do
        expect(EthereumJSONRPC.WebSocket.Mox, :json_rpc, fn _, _ ->
          {:error,
           %{
             "code" => -32601,
             "message" => "Method not found"
           }}
        end)
      end

      # purposely misspell method to trigger error
      assert {:error,
              %{
                "code" => -32601,
                # Message varies by variant, so don't match on it
                "message" => _
              }} =
               %{id: 1, method: "eth_getBlockByNumbe", params: ["earliest", false]}
               |> request()
               |> WebSocket.json_rpc(transport_options)
    end
  end

  describe "subscribe/2" do
    test "can subscribe to newHeads", %{subscribe_named_arguments: subscribe_named_arguments} do
      transport = Keyword.fetch!(subscribe_named_arguments, :transport)
      %WebSocket{web_socket: web_socket_module} = transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      subscription_transport_options =
        case web_socket_module do
          EthereumJSONRPC.WebSocket.Mox ->
            expect(EthereumJSONRPC.WebSocket.Mox, :subscribe, fn _, "newHeads", [] ->
              {:ok,
               %Subscription{
                 reference: make_ref(),
                 subscriber_pid: subscriber_pid,
                 transport: transport,
                 transport_options: transport_options
               }}
            end)

            transport_options

          EthereumJSONRPC.WebSocket.WebSocketClient ->
            update_in(transport_options.web_socket_options, fn %WebSocketClient.Options{} = web_socket_options ->
              %WebSocketClient.Options{web_socket_options | event: "newHeads", params: []}
            end)
        end

      assert {:ok,
              %Subscription{
                reference: subscription_reference,
                subscriber_pid: ^subscriber_pid,
                transport: ^transport,
                transport_options: ^subscription_transport_options
              }} = WebSocket.subscribe("newHeads", [], transport_options)

      assert is_reference(subscription_reference)
    end

    # Infura timeouts on 2018-09-10
    @tag :no_geth
    test "delivers new heads to caller", %{
      block_interval: block_interval,
      subscribe_named_arguments: subscribe_named_arguments
    } do
      %WebSocket{web_socket: web_socket_module} = transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if web_socket_module == EthereumJSONRPC.WebSocket.Mox do
        expect(web_socket_module, :subscribe, fn _, _, _ ->
          subscription = %Subscription{
            reference: make_ref(),
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
      %WebSocket{web_socket: web_socket_module} = transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if web_socket_module == EthereumJSONRPC.WebSocket.Mox do
        subscription = %Subscription{
          reference: make_ref(),
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

    # Infura timeouts on 2018-09-10
    @tag :no_geth
    test "stops messages being sent to subscriber", %{
      block_interval: block_interval,
      subscribe_named_arguments: subscribe_named_arguments
    } do
      %WebSocket{web_socket: web_socket_module} = transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if web_socket_module == EthereumJSONRPC.WebSocket.Mox do
        subscription = %Subscription{
          reference: make_ref(),
          subscriber_pid: subscriber_pid,
          transport: Keyword.fetch!(subscribe_named_arguments, :transport),
          transport_options: transport_options
        }

        web_socket_module
        |> expect(:subscribe, 2, fn pid, _, _ when is_pid(pid) ->
          send(pid, {:subscribe, subscription})

          {:ok, subscription}
        end)
        |> expect(:unsubscribe, fn pid, ^subscription when is_pid(pid) ->
          send(pid, {:unsubscribe, subscription})

          :ok
        end)
      end

      assert {:ok, first_subscription} =
               WebSocket.subscribe("newHeads", [], subscribe_named_arguments[:transport_options])

      assert {:ok, second_subscription} =
               WebSocket.subscribe("newHeads", [], subscribe_named_arguments[:transport_options])

      wait = block_interval * 2

      assert_receive {^first_subscription, {:ok, %{"number" => _}}}, wait
      assert_receive {^second_subscription, {:ok, %{"number" => _}}}, wait

      assert :ok = WebSocket.unsubscribe(first_subscription)

      clear_mailbox()

      # see the message on the second subscription, so that we don't have to wait for the refute_receive, which would
      # wait the full timeout
      assert_receive {^second_subscription, {:ok, %{"number" => _}}}, wait
      refute_receive {^first_subscription, _}
    end

    test "return error if already unsubscribed", %{subscribe_named_arguments: subscribe_named_arguments} do
      %WebSocket{web_socket: web_socket_module} = transport_options = subscribe_named_arguments[:transport_options]
      subscriber_pid = self()

      if web_socket_module == EthereumJSONRPC.WebSocket.Mox do
        subscription = %Subscription{
          reference: make_ref(),
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
