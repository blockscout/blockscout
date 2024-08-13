defmodule EthereumJSONRPC.WebSocket.RetryWorker do
  @moduledoc """
  Stores the unavailable websocket endpoint state and periodically checks if it is already available.
  """

  use GenServer

  require Logger

  alias EthereumJSONRPC.WebSocket.Supervisor, as: WebSocketSupervisor

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def activate(ws_state) do
    GenServer.cast(__MODULE__, {:activate, ws_state})
  end

  def deactivate do
    GenServer.cast(__MODULE__, :deactivate)
  end

  def init(_) do
    schedule_next_retry()

    {:ok, %{active?: false, ws_state: nil}}
  end

  def handle_cast({:activate, ws_state}, state) do
    {:noreply, %{state | active?: true, ws_state: %{ws_state | retry: true}}}
  end

  def handle_cast(:deactivate, state) do
    {:noreply, %{state | active?: false}}
  end

  def handle_info(:retry, %{active?: false} = state) do
    schedule_next_retry()

    {:noreply, state}
  end

  def handle_info(:retry, %{active?: true, ws_state: ws_state} = state) do
    WebSocketSupervisor.start_client(ws_state)

    schedule_next_retry()

    {:noreply, %{state | active?: false}}
  end

  defp schedule_next_retry do
    Process.send_after(self(), :retry, retry_interval())
  end

  defp retry_interval do
    Application.get_env(:ethereum_jsonrpc, __MODULE__)[:retry_interval]
  end
end
