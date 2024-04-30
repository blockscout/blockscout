defmodule BlockScoutWeb.Utility.EventHandlersMetrics do
  @moduledoc """
  Module responsible for periodically setting current event handlers queue length metrics.
  """

  use GenServer

  alias BlockScoutWeb.{MainPageRealtimeEventHandler, RealtimeEventHandler, SmartContractRealtimeEventHandler}
  alias BlockScoutWeb.Prometheus.Instrumenter

  @interval :timer.minutes(1)

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    schedule_next_run()

    {:ok, %{}}
  end

  def handle_info(:set_metrics, state) do
    set_metrics()
    schedule_next_run()

    {:noreply, state}
  end

  defp set_metrics do
    set_handler_metric(MainPageRealtimeEventHandler, :main_page)
    set_handler_metric(RealtimeEventHandler, :common)
    set_handler_metric(SmartContractRealtimeEventHandler, :smart_contract)
  end

  defp set_handler_metric(handler, label) do
    {_, queue_length} = Process.info(Process.whereis(handler), :message_queue_len)
    Instrumenter.event_handler_queue_length(label, queue_length)
  end

  defp schedule_next_run do
    Process.send_after(self(), :set_metrics, @interval)
  end
end
