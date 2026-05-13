# SPDX-License-Identifier: LicenseRef-Blockscout
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
      fetch_cached({scale, options}, scale, fallback_fn)
    else
      fallback_fn.()
    end
  end

  defp fetch_cached(cache_key, scale, fallback_fn) do
    case ConCache.fetch_or_store(@cache_name, cache_key, fn ->
           store_value(fallback_fn, scale)
         end) do
      {:ok, value} -> value
      {:error, _reason} = error -> error
    end
  end

  defp store_value(fallback_fn, scale) do
    case fallback_fn.() do
      {:error, _reason} = error -> error
      result -> {:ok, %ConCache.Item{value: result, ttl: ttl(scale)}}
    end
  end

  @spec cacheable_scale?(scale()) :: boolean()
  def cacheable_scale?(scale), do: scale in @cacheable_scales

  @spec ttl(scale()) :: non_neg_integer()
  def ttl(scale) do
    :explorer
    |> Application.get_env(__MODULE__)
    |> Map.get(scale, 0)
  end
end
