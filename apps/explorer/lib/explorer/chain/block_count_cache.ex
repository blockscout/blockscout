defmodule Explorer.Chain.BlockCountCache do
  @moduledoc """
  Cache for count consensus blocks.
  """

  alias Explorer.Chain

  @tab :block_count_cache
  # 1 minutes
  @cache_period 1_000 * 60
  @key "count"
  @opts_key "opts"

  @spec setup() :: :ok
  def setup do
    if :ets.whereis(@tab) == :undefined do
      :ets.new(@tab, [
        :set,
        :named_table,
        :public,
        write_concurrency: true
      ])
    end

    setup_opts()
    update_cache()

    :ok
  end

  def count do
    initial_cache = {_count, old_current_time} = cached_values()

    {count, _current_time} =
      if current_time() - old_current_time > cache_period() do
        update_cache()

        cached_values()
      else
        initial_cache
      end

    count
  end

  defp update_cache do
    current_time = current_time()
    count = count_from_db()
    tuple = {count, current_time}

    :ets.insert(@tab, {@key, tuple})
  end

  defp setup_opts do
    cache_period = Application.get_env(:explorer, __MODULE__)[:ttl] || @cache_period

    :ets.insert(@tab, {@opts_key, cache_period})
  end

  defp cached_values do
    [{_, cached_values}] = :ets.lookup(@tab, @key)

    cached_values
  end

  defp cache_period do
    [{_, cache_period}] = :ets.lookup(@tab, @opts_key)

    cache_period
  end

  defp count_from_db do
    Chain.fetch_count_consensus_block()
  rescue
    _e ->
      0
  end

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end
end
