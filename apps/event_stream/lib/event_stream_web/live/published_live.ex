defmodule EventStream.PublishedLive do
  use EventStream, :live_view

  @impl true
  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(EventStream.PubSub, "beanstalkd:published")

    events = []

    assigns =
      socket
      |> assign(events: events)
      |> assign(since: DateTime.utc_now())

    {:ok, assigns}
  end

  @impl true
  def handle_info({event}, %{assigns: %{events: events}} = socket) do
    all_events = [event | events] |> Enum.reverse()
    socket = socket |> assign(events: all_events)

    {:noreply, socket}
  end
end
