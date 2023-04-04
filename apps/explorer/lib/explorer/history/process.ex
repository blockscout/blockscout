defmodule Explorer.History.Process do
  @moduledoc """
  Creates the GenServer process used by a Historian to compile_history and to save_records.
  Specifically used by Transaction.History.Historian
  """
  use GenServer
  require Logger

  alias Explorer.History.Historian

  @impl GenServer
  def init([:ok, historian]) do
    init_lag_milliseconds = Application.get_env(:explorer, historian, [])[:init_lag_milliseconds] || 0

    days_to_compile =
      case Application.get_env(:explorer, historian, [])[:days_to_compile_at_init] do
        days when is_integer(days) and days >= 1 -> days
        _ -> 365
      end

    Process.send_after(self(), {:compile_historical_records, days_to_compile}, init_lag_milliseconds)
    {:ok, %{historian: historian}}
  end

  @impl GenServer
  def handle_info({:compile_historical_records, day_count}, state) do
    compile_historical_records(day_count, state.historian)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({_ref, {_, _, {:ok, records}}}, state) do
    successful_compilation(records, state.historian)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({_ref, {day_count, failed_attempts, :error}}, state) do
    failed_compilation(day_count, state.historian, failed_attempts)
    {:noreply, state}
  end

  # Callback that a monitored process has shutdown.
  @impl GenServer
  def handle_info({:DOWN, _, :process, _, _}, state) do
    {:noreply, state}
  end

  # Actions

  @spec successful_compilation(Historian.record(), module()) :: any()
  defp successful_compilation(records, historian) do
    historian.save_records(records)
    schedule_next_compilation()
  end

  defp schedule_next_compilation do
    Logger.info("tx/per day chart: schedule_next_compilation")
    delay = config_or_default(:history_fetch_interval, :timer.minutes(60))
    Process.send_after(self(), {:compile_historical_records, 2}, delay)
  end

  @spec failed_compilation(non_neg_integer(), module(), non_neg_integer()) :: any()
  defp failed_compilation(day_count, historian, failed_attempts) do
    Logger.warn(fn -> "Failed to fetch market history. Trying again." end)
    compile_historical_records(day_count, historian, failed_attempts + 1)
  end

  @spec compile_historical_records(non_neg_integer(), module(), non_neg_integer()) :: Task.t()
  defp compile_historical_records(day_count, historian, failed_attempts \\ 0) do
    Task.Supervisor.async_nolink(Explorer.HistoryTaskSupervisor, fn ->
      Process.sleep(delay(failed_attempts))
      {day_count, failed_attempts, historian.compile_records(day_count)}
    end)
  end

  # Helper
  @typep milliseconds :: non_neg_integer()

  @spec config_or_default(atom(), term(), module()) :: term()
  def config_or_default(key, default, module \\ __MODULE__) do
    Application.get_env(:explorer, module, [])[key] || default
  end

  @spec base_backoff :: milliseconds()
  defp base_backoff do
    config_or_default(:base_backoff, 100)
  end

  @spec delay(non_neg_integer()) :: milliseconds()
  def delay(0), do: 0
  def delay(1), do: base_backoff()

  def delay(failed_attempts) do
    # Simulates 2^n
    multiplier = Enum.reduce(2..failed_attempts, 1, fn _, acc -> 2 * acc end)
    multiplier * base_backoff()
  end
end
