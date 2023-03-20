defmodule EventStream.ContractEventStream do
  @moduledoc """
     Accepts events and pushes them to an external queue (beanstalkd)
  """

  use EventStream.Debug.Constants
  use GenServer
  require Logger
  alias EventStream.{Publisher, Subscriptions}
  alias Explorer.Celo.ContractEvents.{EventMap, EventTransformer}
  alias Explorer.Celo.Telemetry
  alias Phoenix.PubSub

  @doc "Accept a list of events and buffer for sending"
  def enqueue(events) do
    GenServer.cast(__MODULE__, {:enqueue, events})
    {:ok, events}
  end

  # Transform celo contract event to expected json format
  defp transform_event(event) when is_binary(event), do: event

  # don't send debug event to event transformer
  defp transform_event(%{name: @debug_event_name} = event) do
    event |> inspect()
  end

  defp transform_event(event) do
    event
    |> EventMap.celo_contract_event_to_concrete_event()
    |> EventTransformer.to_event_stream_format()
  end

  # callbacks

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @flush_interval_ms 5_000

  @impl true
  def init(buffer) do
    Process.flag(:trap_exit, true)

    flush_time = Application.get_env(:event_stream, :buffer_flush_interval, @flush_interval_ms)
    timer = Process.send_after(self(), :tick, flush_time)

    Subscriptions.subscribe()

    {:ok, %{buffer: buffer, timer: timer}}
  end

  @impl true
  def handle_cast({:enqueue, event}, %{buffer: buffer} = state) do
    {:noreply, %{state | buffer: [event | buffer]}}
  end

  @impl true
  def handle_info(:tick, %{buffer: buffer, timer: timer} = state) do
    Process.cancel_timer(timer)
    failed_events = run(buffer)

    flush_time = Application.get_env(:event_stream, :buffer_flush_interval, @flush_interval_ms)
    new_timer = Process.send_after(self(), :tick, flush_time)

    {:noreply, %{state | buffer: failed_events, timer: new_timer}}
  end

  @impl true
  def handle_info({:chain_event, _type, :realtime, data}, %{buffer: buffer} = state)
      when is_list(data) do
    {:noreply, %{state | buffer: data ++ buffer}}
  end

  @impl true
  def handle_call(:clear, _sender, %{buffer: buffer} = state) do
    {:reply, buffer, %{state | buffer: []}}
  end

  # Don't flush buffer when explicitly disabled
  @impl true
  def terminate(_reason, %{terminate_flush: false} = _state), do: :ok

  # Flush on terminate when buffer is not empty
  @impl true
  def terminate(_reason, %{buffer: buffer} = _state) when buffer != [] do
    Logger.info("Flushing event buffer before shutdown...")
    run(buffer)
  end

  # Unknown termination
  @impl true
  def terminate(reason, _state) do
    Logger.error("Unknown termination - #{inspect(reason)}")
  end

  # attempts to send everything, failed events will be returned to the buffer
  defp run(events) do
    Telemetry.event([:event_stream, :flush], %{}, %{event_count: length(events)})

    failed_events =
      events
      |> List.flatten()
      |> Enum.map(fn event ->
        event
        |> transform_event()
        |> send_event()
      end)
      |> Enum.filter(&(&1 != :ok))
      |> Enum.map(fn {:failed, event} -> event end)

    # return failed events to buffer
    failed_events
  end

  defp send_event(event) do
    :ok = emit_event_send(event)
    Publisher.publish(event)
  end

  defp emit_event_send(event) do
    PubSub.broadcast(EventStream.PubSub, "event_publish_attempt", {event})
  end

  # return current buffer contents and set to empty
  # primarily for testing purposes
  @doc false
  def clear do
    GenServer.call(__MODULE__, :clear)
  end
end
