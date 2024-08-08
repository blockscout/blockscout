defmodule EthereumJSONRPC.WebSocket.WebSocketClientTest do
  use ExUnit.Case

  alias EthereumJSONRPC.Subscription
  alias EthereumJSONRPC.WebSocket.{Registration, WebSocketClient}

  import EthereumJSONRPC, only: [unique_request_id: 0]

  describe "handle_disconnect/2" do
    setup :example_state

    test "treats in-progress unsubscribes as successful", %{state: state} do
      subscription_id = 1

      state = put_subscription(state, subscription_id)

      %Registration{from: {_, ref}} =
        registration = registration(%{type: :unsubscribe, subscription_id: subscription_id})

      state = put_registration(state, registration)

      assert {_, disconnected_state} = WebSocketClient.handle_disconnect(%{attempt_number: 1}, state)

      assert Enum.empty?(disconnected_state.request_id_to_registration)
      assert Enum.empty?(disconnected_state.subscription_id_to_subscription_reference)
      assert Enum.empty?(disconnected_state.subscription_reference_to_subscription)
      assert Enum.empty?(disconnected_state.subscription_reference_to_subscription_id)

      assert_receive {^ref, :ok}
    end

    test "keeps :json_rpc requests for re-requesting on reconnect", %{state: state} do
      state = put_registration(state, %{type: :json_rpc, method: "eth_getBlockByNumber", params: [1, true]})

      assert {_, disconnected_state} = WebSocketClient.handle_disconnect(%{attempt_number: 1}, state)

      assert Enum.count(disconnected_state.request_id_to_registration) == 1
    end

    test "keeps :subscribe requests for re-requesting on reconnect", %{state: state} do
      state = put_registration(state, %{type: :subscribe})

      assert {_, disconnected_state} = WebSocketClient.handle_disconnect(%{attempt_number: 1}, state)

      assert Enum.count(disconnected_state.request_id_to_registration) == 1
    end
  end

  describe "handle_frame/2" do
    setup :example_state

    test "Jason.decode errors are broadcast to all subscribers", %{state: %WebSocketClient{url: url} = state} do
      subscription_id = 1
      subscription_reference = make_ref()
      subscription = subscription(%{url: url, reference: subscription_reference})
      state = put_subscription(state, subscription_id, subscription)

      assert {:ok, ^state} = WebSocketClient.handle_frame({:text, ""}, state)
      assert_receive {^subscription, {:error, %Jason.DecodeError{}}}
    end
  end

  describe "terminate/2" do
    setup :example_state

    test "broadcasts close to all subscribers", %{state: %WebSocketClient{url: url} = state} do
      subscription_id = 1
      subscription_reference = make_ref()
      subscription = subscription(%{url: url, reference: subscription_reference})
      state = put_subscription(state, subscription_id, subscription)

      assert :ok = WebSocketClient.terminate(:close, state)
      assert_receive {^subscription, :close}
    end
  end

  describe "reconnect" do
    setup do
      dispatch = :cowboy_router.compile([{:_, [{"/websocket", EthereumJSONRPC.WebSocket.Cowboy.WebSocketHandler, []}]}])
      {:ok, _} = :cowboy.start_tls(EthereumJSONRPC.WebSocket.Cowboy, [], env: [dispatch: dispatch])

      on_exit(fn ->
        :ranch.stop_listener(EthereumJSONRPC.WebSocket.Cowboy)
      end)

      port = :ranch.get_port(EthereumJSONRPC.WebSocket.Cowboy)

      pid = start_supervised!({WebSocketClient, ["ws://localhost:#{port}/websocket", [keepalive: :timer.hours(1)], []]})

      %{pid: pid, port: port}
    end
  end

  defp example_state(_) do
    %{state: %WebSocketClient{url: "ws://example.com"}}
  end

  defp put_registration(%WebSocketClient{} = state, %Registration{request: %{id: request_id}} = registration) do
    %WebSocketClient{state | request_id_to_registration: %{request_id => registration}}
  end

  defp put_registration(%WebSocketClient{} = state, map) when is_map(map) do
    put_registration(state, registration(map))
  end

  defp put_subscription(%WebSocketClient{url: url} = state, subscription_id) when is_integer(subscription_id) do
    subscription_reference = make_ref()
    put_subscription(state, subscription_id, subscription(%{url: url, reference: subscription_reference}))
  end

  defp put_subscription(
         %WebSocketClient{url: url} = state,
         subscription_id,
         %Subscription{
           reference: subscription_reference,
           transport_options: %EthereumJSONRPC.WebSocket{url: url}
         } = subscription
       ) do
    %WebSocketClient{
      state
      | subscription_id_to_subscription_reference: %{subscription_id => subscription_reference},
        subscription_reference_to_subscription: %{subscription_reference => subscription},
        subscription_reference_to_subscription_id: %{subscription_reference => subscription_id}
    }
  end

  defp registration(%{type: :subscribe = type}) do
    %Registration{
      type: type,
      from: {self(), make_ref()},
      request: %{id: unique_request_id(), method: "eth_subscribe", params: ["newHeads"]}
    }
  end

  defp registration(%{type: :unsubscribe = type, subscription_id: subscription_id}) do
    %Registration{
      type: type,
      from: {self(), make_ref()},
      request: %{id: unique_request_id(), method: "eth_unsubscribe", params: [subscription_id]}
    }
  end

  defp registration(%{type: type, method: method, params: params}) do
    %Registration{
      type: type,
      from: {self(), make_ref()},
      request: %{id: unique_request_id(), method: method, params: params}
    }
  end

  defp subscription(%{reference: reference, url: url}) do
    %Subscription{
      reference: reference,
      subscriber_pid: self(),
      transport: EthereumJSONRPC.WebSocket,
      transport_options: %EthereumJSONRPC.WebSocket{
        url: url,
        web_socket: WebSocketClient,
        web_socket_options: %WebSocketClient.Options{
          web_socket: self(),
          event: "newHeads",
          params: []
        }
      }
    }
  end
end
