defmodule Explorer.ThirdPartyIntegrations.UniversalProxy.SocketHandler do
  @moduledoc """
  A simple WebSocket proxy handler that relays messages between a client and a target WebSocket server.
  """
  @behaviour :cowboy_websocket
  alias Explorer.ThirdPartyIntegrations.UniversalProxy.TargetClient

  # called after HTTP handshake
  @spec init(req :: :cowboy_req.req(), opts :: keyword()) ::
          {:cowboy_websocket, :cowboy_req.req(), map()}
  def init(req, opts) do
    {:cowboy_websocket, req, %{target: nil, opts: opts}}
  end

  # called once WebSocket upgraded
  @spec websocket_init(state :: map()) :: {:ok, map()}
  def websocket_init(state) do
    {:ok, target_pid} = TargetClient.start_link(self(), state.opts[:url])
    {:ok, %{state | target: target_pid}}
  end

  @spec websocket_handle(frame :: tuple(), state :: map()) :: {:ok, map()} | {:reply, tuple(), map()}
  def websocket_handle({:text, msg}, %{target: target_pid} = state) do
    TargetClient.forward(target_pid, msg)
    {:ok, state}
  end

  @spec websocket_handle(other :: any(), state :: map()) :: {:ok, map()}
  def websocket_handle(_other, state), do: {:ok, state}

  @spec websocket_info(msg :: tuple(), state :: map()) :: {:ok, map()} | {:reply, tuple(), map()}
  def websocket_info({:from_target, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  def websocket_info(_, state), do: {:ok, state}

  @spec websocket_terminate(reason :: any(), state :: map()) :: :ok
  def websocket_terminate(_reason, _state), do: :ok
end
