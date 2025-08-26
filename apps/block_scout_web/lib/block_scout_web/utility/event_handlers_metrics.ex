defmodule BlockScoutWeb.Utility.EventHandlersMetrics do
  @moduledoc """
  Module responsible for periodically setting current event handlers queue length metrics.
  """

  use GenServer

  alias BlockScoutWeb.RealtimeEventHandlers.{
    Main,
    MainPage,
    SmartContract,
    TokenTransfer
  }

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
    set_handler_metric(MainPage, :main_page)
    set_handler_metric(Main, :common)
    set_handler_metric(SmartContract, :smart_contract)
    set_handler_metric(TokenTransfer, :token_transfer)
  end

  defp set_handler_metric(handler, label) do
    queue_length =
      with pid when is_pid(pid) <- Process.whereis(handler),
           {:message_queue_len, length} <- Process.info(pid, :message_queue_len) do
        length
      else
        _ -> 0
      end

    Instrumenter.event_handler_queue_length(label, queue_length)
  end

  defp schedule_next_run do
    Process.send_after(self(), :set_metrics, @interval)
  end
end
