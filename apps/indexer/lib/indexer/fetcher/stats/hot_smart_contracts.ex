defmodule Indexer.Fetcher.Stats.HotSmartContracts do
  @moduledoc """
  This module defines the HotSmartContracts fetcher for indexing hot contracts.
  """
  use Indexer.Fetcher, restart: :permanent

  use GenServer
  alias Explorer.Chain
  alias Explorer.Stats.HotSmartContracts

  require Logger

  @retry_interval 10_000
  @max_days_ago 30

  @impl GenServer
  def init(opts) do
    GenServer.cast(__MODULE__, :check_completeness)

    schedule_next_day_fetch()

    {:ok, opts}
  end

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def handle_info({:fetch_for_date, date, new_day?}, state) do
    with {:ok, hot_smart_contracts} <- HotSmartContracts.aggregate_hot_smart_contracts_for_date(date),
         {:ok, _} <- Chain.import(%{hot_smart_contracts_daily: %{params: hot_smart_contracts}, timeout: :infinity}) do
      if new_day? do
        schedule_next_day_fetch()
        HotSmartContracts.delete_older_than(Date.add(date, 1 - @max_days_ago))
      end

      Logger.info("Hot contracts fetched for #{date}")
    else
      {:error, error} ->
        Process.send_after(self(), {:fetch_for_date, date, new_day?}, @retry_interval)
        Logger.error("Error fetching hot contracts for #{date}: #{inspect(error)}")
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:check_completeness, state) do
    indexed_dates = HotSmartContracts.indexed_dates()

    today = Date.utc_today()

    Enum.each(1..@max_days_ago, fn days_ago ->
      date = Date.add(today, -days_ago)

      if date not in indexed_dates do
        Process.send_after(self(), {:fetch_for_date, date, false}, @retry_interval)
      end
    end)

    {:noreply, state}
  end

  defp schedule_next_day_fetch do
    today = Date.utc_today()
    now = DateTime.utc_now()
    next_day = Date.utc_today() |> Date.add(1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    delay = DateTime.diff(next_day, now, :millisecond)
    Process.send_after(self(), {:fetch_for_date, today, true}, delay)
  end
end
