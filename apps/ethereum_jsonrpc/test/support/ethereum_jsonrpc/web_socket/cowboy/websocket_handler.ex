# See https://github.com/ninenines/cowboy/blob/2.6.1/examples/websocket/src/ws_h.erl
# See https://ninenines.eu/docs/en/cowboy/2.6/guide/ws_handlers/
defmodule EthereumJSONRPC.WebSocket.Cowboy.WebSocketHandler do
  @behaviour :cowboy_websocket

  defstruct subscription_id_set: MapSet.new(),
            new_heads_timer_reference: nil

  @impl :cowboy_websocket
  def init(request, []) do
    {:cowboy_websocket, request, %__MODULE__{}}
  end

  @impl :cowboy_websocket
  def websocket_handle(
        {:text, text},
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

        {:reply, frame,
         %__MODULE__{
           state
           | new_heads_timer_reference: new_heads_timer_reference,
             subscription_id_set: MapSet.put(subscription_id_set, subscription_id)
         }}

      %{"id" => id, "method" => "echo", "params" => params} ->
        response = %{id: id, result: params}
        frame = {:text, Jason.encode!(response)}
        {:reply, frame, state}
    end
  end

  @impl :cowboy_websocket
  def websocket_info(:new_head, %__MODULE__{subscription_id_set: subscription_id_set} = state) do
    frames =
      Enum.map(subscription_id_set, fn subscription_id ->
        response = %{method: "eth_subscription", params: %{result: %{}, subscription: subscription_id}}
        {:text, Jason.encode!(response)}
      end)

    {:reply, frames, state}
  end

  @impl :cowboy_websocket
  def terminate(_reason, _request, _state) do
    :ok
  end
end
