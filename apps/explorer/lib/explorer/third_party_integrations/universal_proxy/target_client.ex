defmodule Explorer.ThirdPartyIntegrations.UniversalProxy.TargetClient do
  @moduledoc """
  A WebSocket client that connects to a target WebSocket server and forwards messages to/from a
  parent process.
  """
  use WebSockex

  def start_link(parent_pid, url) do
    WebSockex.start_link(url, __MODULE__, %{
      parent: parent_pid
    })
  end

  ## Callbacks

  @impl true
  def handle_frame({:text, msg}, %{parent: parent} = state) do
    send(parent, {:from_target, msg})
    {:ok, state}
  end

  def handle_frame({:binary, msg}, %{parent: parent} = state) do
    send(parent, {:from_target, msg})
    {:ok, state}
  end

  @spec forward(pid :: pid(), msg :: String.t()) :: :ok | {:error, term()}
  def forward(pid, msg) do
    WebSockex.send_frame(pid, {:text, msg})
  end
end
