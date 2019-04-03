defmodule Explorer.Chain.BlockNumberCache do
  @moduledoc """
  Cache for max and min block numbers.
  """

  alias Explorer.Chain

  @tab :block_number_cache
  # 30 minutes
  @cache_period 1_000 * 60 * 30
  @key "min_max"
  @opts_key "opts"

  @spec setup(Keyword.t()) :: :ok
  def setup(opts \\ []) do
    if :ets.whereis(@tab) == :undefined do
      :ets.new(@tab, [
        :set,
        :named_table,
        :public,
        write_concurrency: true
      ])
    end

    update_cache()
    setup_opts(opts)

    :ok
  end

  def max_number do
    value(:max)
  end

  def min_number do
    value(:min)
  end

  def min_and_max_numbers do
    value(:all)
  end

  defp value(type) do
    initial_cache = {_min, _max, old_current_time} = cached_values()

    {min, max, _current_time} =
      if current_time() - old_current_time > cache_period() do
        update_cache()

        cached_values()
      else
        initial_cache
      end

    case type do
      :max -> max
      :min -> min
      :all -> {min, max}
    end
  rescue
    _e ->
      case type do
        :max -> 0
        :min -> 0
        :all -> {0, 0}
      end
  end

  defp update_cache do
    current_time = current_time()
    {min, max} = Chain.fetch_min_and_max_block_numbers()
    tuple = {min, max, current_time}

    :ets.insert(@tab, {@key, tuple})
  rescue
    _e ->
      :ok
  end

  defp setup_opts(opts) do
    cache_period = opts[:cache_period] || @cache_period

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

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end
end
