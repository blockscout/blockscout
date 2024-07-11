defmodule EthereumJSONRPC.WebSocket.Case.Mox do
  @moduledoc """
  `EthereumJSONRPC.WebSocket.Case` using `Mox`
  """

  import ExUnit.Callbacks, only: [start_supervised!: 1]
  import Mox

  alias EthereumJSONRPC.Subscription

  @block_interval 250

  def setup do
    web_socket_module = EthereumJSONRPC.WebSocket.Mox

    web_socket_module
    |> allow(self(), supervisor())
    |> stub(:child_spec, fn arguments ->
      Supervisor.child_spec(
        %{
          id: web_socket_module,
          start: {web_socket_module, :start_link, [arguments]}
        },
        []
      )
    end)
    |> stub(:start_link, fn _, _ ->
      Task.start_link(__MODULE__, :loop, [%{}])
    end)

    url = "wss://example.com/ws"
    web_socket = start_supervised!(%{id: :ws_client, start: {web_socket_module, :start_link, [url, []]}})

    %{
      block_interval: @block_interval,
      subscribe_named_arguments: [
        transport: EthereumJSONRPC.WebSocket,
        transport_options: %EthereumJSONRPC.WebSocket{
          web_socket: web_socket_module,
          web_socket_options: %{web_socket: web_socket},
          url: url
        }
      ]
    }
  end

  def loop(%{subscription: subscription, timer_reference: timer_reference}) do
    receive do
      {:unsubscribe, ^subscription} ->
        {:ok, :cancel} = :timer.cancel(timer_reference)
        loop(%{})
    end
  end

  def loop(%{}) do
    receive do
      {:subscribe, %Subscription{subscriber_pid: subscriber_pid} = subscription} ->
        {:ok, timer_reference} =
          :timer.send_interval(@block_interval, subscriber_pid, {subscription, {:ok, %{"number" => "0x1"}}})

        loop(%{subscription: subscription, timer_reference: timer_reference})
    end
  end

  defp supervisor do
    case ExUnit.OnExitHandler.get_supervisor(self()) do
      {:ok, nil} ->
        {:ok, sup} = Supervisor.start_link([], strategy: :one_for_one, max_restarts: 1_000_000, max_seconds: 1)
        ExUnit.OnExitHandler.put_supervisor(self(), sup)
        sup

      {:ok, sup} ->
        sup
    end
  end
end
