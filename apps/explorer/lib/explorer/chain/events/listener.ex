defmodule Explorer.Chain.Events.Listener do
  @moduledoc """
  Listens and dispatches events
  """

  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, state, {:continue, :listen_to_source}}
  end

  def handle_continue(:listen_to_source, %{event_source: source} = state) do
    source_state = source.setup_source()
    {:noreply, Map.merge(state, source_state)}
  end

  def handle_info(msg, %{event_source: source} = state) do
    msg
    |> source.handle_source_msg()
    |> broadcast()

    {:noreply, state}
  end

  defp broadcast({:chain_event, event_type} = event) do
    Registry.dispatch(Registry.ChainEvents, event_type, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, event)
      end
    end)
  end

  defp broadcast({:chain_event, event_type, broadcast_type, _data} = event) do
    Registry.dispatch(Registry.ChainEvents, {event_type, broadcast_type}, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, event)
      end
    end)
  end
end
