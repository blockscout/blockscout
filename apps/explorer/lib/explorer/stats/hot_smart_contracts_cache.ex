defmodule Explorer.Stats.HotSmartContractsCache do
  @moduledoc """
  Cache for hot smart contracts computed from realtime transaction cohorts.
  """

  alias Explorer.Stats.HotSmartContracts

  @cache_name :hot_smart_contracts
  @cacheable_scales ~w(5m 1h 3h)

  @type scale :: String.t()

  @spec cache_name() :: atom()
  def cache_name, do: @cache_name

  @spec fetch(scale(), keyword(), (-> [HotSmartContracts.t()] | {:error, :not_found})) ::
          [HotSmartContracts.t()] | {:error, :not_found}
  def fetch(scale, options, fallback_fn) when is_function(fallback_fn, 0) do
    if cacheable_scale?(scale) do
      cache_key = {scale, options}

      case ConCache.get(@cache_name, cache_key) do
        nil ->
          fallback_fn.()
          |> maybe_put_into_cache(cache_key, scale)

        cached_value ->
          cached_value
      end
    else
      fallback_fn.()
    end
  end

  @spec cacheable_scale?(scale()) :: boolean()
  def cacheable_scale?(scale), do: scale in @cacheable_scales

  @spec ttl(scale()) :: non_neg_integer()
  def ttl(scale) do
    :explorer
    |> Application.get_env(__MODULE__, [])
    |> ttl_by_scale(scale)
  end

  defp ttl_by_scale(config, scale) when is_map(config), do: Map.get(config, scale, 0)

  defp maybe_put_into_cache(result, cache_key, scale) do
    if match?({:error, _reason}, result) do
      result
    else
      ConCache.put(@cache_name, cache_key, %ConCache.Item{value: result, ttl: ttl(scale)})
      result
    end
  end
end
