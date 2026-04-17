defmodule Indexer.Fetcher.Stats.HotSmartContracts do
  @moduledoc """
  This module defines the HotSmartContracts fetcher for indexing hot contracts.
  """
  use Indexer.Fetcher, restart: :permanent

  use GenServer

  alias Explorer.Chain
  alias Explorer.Chain.Block
  alias Explorer.Stats.HotSmartContracts

  require Logger

  @retry_interval 10_000
  @max_days_ago 30
  @min_chain_age_days 30

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    {:ok, opts, {:continue, :check_chain_age}}
  end

  @impl GenServer
  def handle_continue(:check_chain_age, state) do
    process_chain_age_check()
    {:noreply, state}
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
  def handle_info(:check_chain_age, state) do
    process_chain_age_check()
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
    schedule_message_on_the_next_day({:fetch_for_date, Date.utc_today(), true})
  end

  defp schedule_startup_check do
    schedule_message_on_the_next_day(:check_chain_age)
  end

  defp schedule_message_on_the_next_day(payload) do
    now = DateTime.utc_now()
    next_day = Date.utc_today() |> Date.add(1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    delay = DateTime.diff(next_day, now, :millisecond)
    Process.send_after(self(), payload, delay)
  end

  defp process_chain_age_check do
    case check_chain_age() do
      :ok ->
        GenServer.cast(__MODULE__, :check_completeness)
        schedule_next_day_fetch()

      {:wait, delay_ms} ->
        Logger.info(
          "Hot contracts module delayed: chain is less than #{@min_chain_age_days} days old. Rescheduling startup check."
        )

        Process.send_after(self(), :check_chain_age, delay_ms)

      {:error, :block_not_found} ->
        Logger.info("Hot contracts module delayed: second block not found. Rescheduling startup check for next day.")

        schedule_startup_check()

      {:error, reason} ->
        Logger.warning(
          "Hot contracts module delayed: error checking chain age (#{inspect(reason)}). Rescheduling startup check for next day."
        )

        schedule_startup_check()
    end
  end

  defp check_chain_age do
    # Get the second block (ordered by number ascending) timestamp
    case Block.fetch_second_block_in_database() do
      {:ok, block} ->
        now = DateTime.utc_now()
        age_days = DateTime.diff(now, block.timestamp, :day)

        if age_days >= @min_chain_age_days do
          :ok
        else
          # Calculate delay until chain reaches 30 days old, or next day if that's sooner
          target_date = DateTime.add(block.timestamp, @min_chain_age_days, :day)
          next_day = Date.utc_today() |> Date.add(1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

          delay_target = DateTime.diff(target_date, now, :millisecond)
          delay_next_day = DateTime.diff(next_day, now, :millisecond)

          # Use the smaller delay (either until 30 days or next day, whichever comes first)
          delay_ms = delay_target |> min(delay_next_day) |> max(0)

          {:wait, delay_ms}
        end

      {:error, :not_found} ->
        {:error, :block_not_found}
    end
  rescue
    e ->
      {:error, {:exception, e}}
  end
end
