defmodule Explorer.Counters.Helper do
  @moduledoc """
    A helper for caching modules
  """

  @ets_opts [
    :set,
    :named_table,
    :public,
    read_concurrency: true
  ]

  @doc """
    Returns the current time in milliseconds since the Unix epoch.

    This function retrieves the current UTC time and converts it to Unix
    timestamp in milliseconds.

    ## Returns
    - The number of milliseconds since the Unix epoch.
  """
  @spec current_time() :: non_neg_integer()
  def current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end

  def fetch_from_ets_cache(key, cache_name, default \\ nil) do
    case :ets.lookup(cache_name, key) do
      [{_, value}] ->
        value

      [] ->
        default
    end
  end

  def put_into_ets_cache(cache_name, key, value) do
    :ets.insert(cache_name, {key, value})
  end

  def create_cache_table(cache_name) do
    if :ets.whereis(cache_name) == :undefined do
      :ets.new(cache_name, @ets_opts)
    end
  end
end
