defmodule EventStream.ReceivedLive do
  use EventStream, :live_view

  alias EventStream.Subscriptions

  @impl true
  def mount(_params, _session, socket) do
    Subscriptions.subscribe()

    events = []

    assigns =
      socket
      |> assign(events: events)
      |> assign(max_block: "n/a")
      |> assign(since: DateTime.utc_now())

    {:ok, assigns}
  end

  @impl true
  def handle_info({:chain_event, _type, :realtime, data}, %{assigns: %{events: events}} = socket) do
    all_events = events ++ data

    socket =
      socket
      |> assign(events: all_events)
      |> assign(max_block: max_block_number(all_events))

    {:noreply, socket}
  end

  def max_block_number(events) do
    max_event = events |> Enum.max_by(& &1.block_number)
    max_event.block_number
  end
end
