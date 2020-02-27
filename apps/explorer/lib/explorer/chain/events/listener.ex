defmodule Explorer.Chain.Events.Listener do
  @moduledoc """
  Listens and publishes events from PG
  """

  use GenServer

  alias Postgrex.Notifications
  import Explorer.Chain, only: [extract_db_name: 1]

  def start_link(_) do
    GenServer.start_link(__MODULE__, "chain_event", name: __MODULE__)
  end

  def init(channel) do
    explorer_repo =
      :explorer
      |> Application.get_env(Explorer.Repo)

    db_url = explorer_repo[:url]

    {:ok, pid} =
      explorer_repo
      |> Keyword.put(:database, extract_db_name(db_url))
      |> Notifications.start_link()

    ref = Notifications.listen!(pid, channel)

    {:ok, {pid, ref, channel}}
  end

  def handle_info({:notification, _pid, _ref, _topic, payload}, state) do
    payload
    |> decode_payload!()
    |> broadcast()

    {:noreply, state}
  end

  # sobelow_skip ["Misc.BinToTerm"]
  defp decode_payload!(payload) do
    payload
    |> Base.decode64!()
    |> :erlang.binary_to_term()
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
