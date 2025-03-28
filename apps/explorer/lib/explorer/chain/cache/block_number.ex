defmodule Explorer.Chain.Cache.BlockNumber do
  @moduledoc """
  Cache for max and min block numbers.
  """

  @type value :: non_neg_integer()

  use Explorer.Chain.MapCache,
    name: :block_number,
    keys: [:min, :max],
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  alias Explorer.Chain

  def handle_update(_key, nil, value), do: {:ok, value}

  def handle_update(:min, old_value, new_value), do: {:ok, min(new_value, old_value)}

  def handle_update(:max, old_value, new_value), do: {:ok, max(new_value, old_value)}

  # Handles cache misses by fetching block numbers from the database.
  #
  # When the cache is enabled, updates it with the fetched value. Otherwise,
  # returns the value without caching.
  #
  # ## Parameters
  # - `key`: Either `:min` for lowest block number or `:max` for highest block number
  #
  # ## Returns
  # - `{:update, non_neg_integer()}` when caching is enabled
  # - `{:return, non_neg_integer()}` when caching is disabled
  @spec handle_fallback(key :: :min | :max) :: {:update, non_neg_integer()} | {:return, non_neg_integer()}
  defp handle_fallback(key) do
    result = fetch_from_db(key)

    if Application.get_env(:explorer, __MODULE__)[:enabled] do
      {:update, result}
    else
      {:return, result}
    end
  end

  # Retrieves the minimum or maximum consensus block number from the database.
  #
  # ## Parameters
  # - `key`: Either `:min` for lowest block number or `:max` for highest block number
  #
  # ## Returns
  # - A non-negative integer representing the requested block number, or 0 if none found
  @spec fetch_from_db(:min | :max) :: non_neg_integer()
  defp fetch_from_db(key) do
    case key do
      :min -> Chain.fetch_min_block_number()
      :max -> Chain.fetch_max_block_number()
    end
  end
end
