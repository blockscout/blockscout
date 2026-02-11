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
    Process.send_after(self(), {:compile_historical_records, 2}, calculate_delay_until_next_midnight())
  end

  @spec failed_compilation(non_neg_integer(), module(), non_neg_integer()) :: any()
  defp failed_compilation(day_count, historian, failed_attempts) do
    Logger.warning(fn -> "Failed to fetch market history. Trying again." end)
    compile_historical_records(day_count, historian, failed_attempts + 1)
  end

  @spec compile_historical_records(non_neg_integer(), module(), non_neg_integer()) :: Task.t()
  defp compile_historical_records(day_count, historian, failed_attempts \\ 0) do
    Task.Supervisor.async_nolink(Explorer.HistoryTaskSupervisor, fn ->
      Process.sleep(delay(failed_attempts))

      try do
        {day_count, failed_attempts, historian.compile_records(day_count)}
      rescue
        exception ->
          Logger.error(fn ->
            [
              "Error on compile_historical_records (day_count=#{day_count}, failed_attempts=#{failed_attempts}):",
              Exception.format(:error, exception)
            ]
          end)

          {day_count, failed_attempts, :error}
      end
    end)
  end

  # Helper
  @typep milliseconds :: non_neg_integer()

  @doc """
    Retrieves a configuration value from the `:explorer` application or returns a default if not set.

    ## Parameters
    - `key`: The configuration key to look up.
    - `default`: The default value to return if the configuration is not found.
    - `module`: The module to look up the configuration for. Defaults to the
      calling module.

    ## Returns
    - The configuration value if found in the :explorer application settings,
      otherwise the default value.
  """
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

  defp calculate_delay_until_next_midnight do
    now = DateTime.utc_now()
    # was added for testing possibility
    time_to_fetch_at = config_or_default(:time_to_fetch_at, Time.new!(0, 0, 1, 0))
    days_to_add = config_or_default(:days_to_add, 1)
    tomorrow = DateTime.new!(Date.add(Date.utc_today(), days_to_add), time_to_fetch_at, now.time_zone)

    DateTime.diff(tomorrow, now, :millisecond)
  end
end
