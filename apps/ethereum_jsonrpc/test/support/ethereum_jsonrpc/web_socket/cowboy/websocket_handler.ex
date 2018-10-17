# See https://github.com/ninenines/cowboy/blob/1.1.x/examples/websocket/src/ws_handler.erl
defmodule EthereumJSONRPC.WebSocket.Cowboy.WebSocketHandler do
  @behaviour :cowboy_websocket_handler

  defstruct subscription_id_set: MapSet.new(),
            new_heads_timer_reference: nil

  def init({:tcp, :http}, _request, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  @impl :cowboy_websocket_handler
  def websocket_init(_transport_name, request, _opts) do
    {:ok, request, %__MODULE__{}}
  end

  @impl :cowboy_websocket_handler
  def websocket_handle(
        {:text, text},
        request,
        %__MODULE__{subscription_id_set: subscription_id_set, new_heads_timer_reference: new_heads_timer_reference} =
          state
      ) do
    json = Jason.decode!(text)

    case json do
      %{"id" => id, "method" => "eth_subscribe", "params" => ["newHeads"]} ->
        subscription_id = :erlang.unique_integer()
        response = %{id: id, result: subscription_id}
        frame = {:text, Jason.encode!(response)}

        new_heads_timer_reference =
          case new_heads_timer_reference do
            nil ->
              {:ok, timer_reference} = :timer.send_interval(10, :new_head)
              timer_reference

            _ ->
              new_heads_timer_reference
          end

        {:reply, frame, request,
         %__MODULE__{
           state
           | new_heads_timer_reference: new_heads_timer_reference,
             subscription_id_set: MapSet.put(subscription_id_set, subscription_id)
         }}

      %{"id" => id, "method" => "echo", "params" => params} ->
        response = %{id: id, result: params}
        frame = {:text, Jason.encode!(response)}
        {:reply, frame, request, state}
    end
  end

  @impl :cowboy_websocket_handler
  def websocket_info(:new_head, request, %__MODULE__{subscription_id_set: subscription_id_set} = state) do
    frames =
      Enum.map(subscription_id_set, fn subscription_id ->
        response = %{method: "eth_subscription", params: %{result: %{}, subscription: subscription_id}}
        {:text, Jason.encode!(response)}
      end)

    {:reply, frames, request, state}
  end

  @impl :cowboy_websocket_handler
  def websocket_terminate(_reason, _request, _state) do
    :ok
  end
end
