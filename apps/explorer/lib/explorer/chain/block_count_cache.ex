defmodule Explorer.Chain.BlockCountCache do
  @moduledoc """
  Cache for count consensus blocks.
  """

  alias Explorer.Chain
  use GenServer

  @tab :block_count_cache
  # 1 minutes
  @cache_period 1_000 * 60
  @key "count"
  @opts "ttl"

  def start_link(params) do
    name = Keyword.get(params, :name, __MODULE__)
    GenServer.start_link(__MODULE__, params, name: name)
  end

  def init(_) do
    if :ets.whereis(@tab) == :undefined do
      :ets.new(@tab, [
        :set,
        :named_table,
        :public,
        write_concurrency: true
      ])
    end

    cache_period = Application.get_env(:explorer, __MODULE__)[:ttl] || @cache_period
    :ets.insert(@tab, {@opts, cache_period})

    {:ok, nil}
  end

  def count(name \\ __MODULE__) do
    case :ets.lookup(@tab, @key) do
      [{_, {cached_values, timestamp}}] ->
        if timeout?(timestamp), do: send(name, :update_cache)

        cached_values

      [] ->
        send(name, :update_cache)
        nil
    end
  end

  def handle_info(:set_timer, nil) do
    [{_, cache_period}] = :ets.lookup(@tab, @opts)
    timer = Process.send_after(self(), :update_cache, cache_period)
    {:noreply, timer}
  end

  def handle_info(:update_cache, timer) do
    if timer, do: Process.cancel_timer(timer)

    count = count_from_db()

    :ets.insert(@tab, {@key, {count, current_time()}})

    send(self(), :set_timer)

    {:noreply, nil}
  end

  defp count_from_db do
    Chain.fetch_count_consensus_block()
  end

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end

  defp timeout?(timestamp) do
    [{_, cache_period}] = :ets.lookup(@tab, @opts)
    current_time() - timestamp > cache_period
  end
end
