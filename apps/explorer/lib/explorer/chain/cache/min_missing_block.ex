defmodule Explorer.Chain.Cache.MinMissingBlockNumber do
  @moduledoc """
  Caches min missing block number (break in the chain).
  """

  use GenServer

  alias Explorer.Chain
  alias Explorer.Chain.Cache.BlockNumber

  @default_batch_size 100_000
  @normal_interval 10
  @increased_interval :timer.minutes(20)
  @default_last_fetched_number -1

  @doc """
  Starts a process to periodically update the % of blocks indexed.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    schedule_next_consolidation(@normal_interval)
    {:ok, %{last_fetched_number: @default_last_fetched_number}}
  end

  def fetch_min_missing_block(last_fetched_number) do
    from = last_fetched_number + 1
    to = last_fetched_number + batch_size()
    max_block_number = BlockNumber.get_max() - 1

    {corrected_to, continue?} = if to >= max_block_number, do: {max_block_number, false}, else: {to, true}

    result = Chain.fetch_min_missing_block_cache(from, corrected_to)

    cond do
      not is_nil(result) ->
        params = %{
          counter_type: "min_missing_block_number",
          value: result
        }

        Chain.upsert_last_fetched_counter(params)
        schedule_next_consolidation(@increased_interval)
        @default_last_fetched_number

      continue? ->
        schedule_next_consolidation(@normal_interval)
        corrected_to

      true ->
        schedule_next_consolidation(@increased_interval)
        @default_last_fetched_number
    end
  end

  defp schedule_next_consolidation(interval) do
    Process.send_after(self(), :fetch_min_missing_block, interval)
  end

  @impl true
  def handle_info(:fetch_min_missing_block, %{last_fetched_number: last_fetched_number} = state) do
    new_last_number = fetch_min_missing_block(last_fetched_number)
    {:noreply, %{state | last_fetched_number: new_last_number}}
  end

  defp batch_size do
    Application.get_env(:explorer, __MODULE__)[:batch_size] || @default_batch_size
  end
end
