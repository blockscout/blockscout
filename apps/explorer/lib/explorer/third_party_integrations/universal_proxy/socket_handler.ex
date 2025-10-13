defmodule Explorer.ThirdPartyIntegrations.UniversalProxy.SocketHandler do
  @moduledoc """
  A simple WebSocket proxy handler that relays messages between a client and a target WebSocket server.
  """
  @behaviour :cowboy_websocket
  alias Explorer.ThirdPartyIntegrations.UniversalProxy.TargetClient

  # called after HTTP handshake
  @spec init(req :: :cowboy_req.req(), opts :: keyword()) ::
          {:cowboy_websocket, :cowboy_req.req(), map(), map()}
  def init(req, opts) do
    {:cowboy_websocket, req, %{target: nil, opts: opts}, %{idle_timeout: :infinity}}
  end

  # called once WebSocket upgraded
  @spec websocket_init(state :: map()) :: {:ok, map()}
  def websocket_init(state) do
    case TargetClient.start_link(self(), state.opts[:url]) do
      {:ok, target_pid} ->
        Process.monitor(target_pid)
        {:ok, %{state | target: target_pid}}

      {:error, reason} ->
        # Send error to client and close connection
        {:reply, {:close, 1011, "Failed to connect to target: #{inspect(reason)}"}, state}
    end
  end

  @spec websocket_handle(frame :: tuple(), state :: map()) :: {:ok, map()} | {:reply, tuple(), map()}
  def websocket_handle({:text, msg}, %{target: target_pid} = state) when not is_nil(target_pid) do
    case TargetClient.forward(target_pid, msg) do
      :ok ->
        {:ok, state}

      {:error, _reason} ->
        {:reply, {:close, 1011, "Target connection error"}, state}
    end
  end

  def websocket_handle({:text, _msg}, state) do
    {:reply, {:close, 1011, "No target connection"}, state}
  end

  @spec websocket_handle(other :: any(), state :: map()) :: {:ok, map()}
  def websocket_handle(_other, state), do: {:ok, state}

  def websocket_info({:DOWN, _ref, :process, pid, _reason}, %{target: pid} = state) do
    {:reply, {:close, 1011, "Target connection lost"}, %{state | target: nil}}
  end

  def websocket_info({:EXIT, pid, _reason}, %{target: pid} = state) do
    {:reply, {:close, 1011, "Target connection lost"}, %{state | target: nil}}
  end

  @spec websocket_info(msg :: tuple(), state :: map()) :: {:ok, map()} | {:reply, tuple(), map()}
  def websocket_info({:from_target, msg, :type, type}, state) do
    {:reply, {type, msg}, state}
  end

  def websocket_info(_, state), do: {:ok, state}

  @spec websocket_terminate(reason :: any(), state :: map()) :: :ok
  def websocket_terminate(_reason, %{target: target_pid}) when not is_nil(target_pid) do
    Process.exit(target_pid, :shutdown)
    :ok
  end

  def websocket_terminate(_reason, _state), do: :ok
end
