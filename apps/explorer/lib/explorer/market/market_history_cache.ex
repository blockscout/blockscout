defmodule Explorer.Market.MarketHistoryCache do
  @moduledoc """
  Caches recent market history.
  """

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Cache.Counters.Helper
  alias Explorer.Market.MarketHistory
  alias Explorer.Repo

  @cache_name :market_history
  @last_update_key :last_update
  @history_key :history
  # 6 hours
  @recent_days 30

  def fetch(secondary_coin? \\ false) do
    @last_update_key
    |> cache_expired?()
    |> if do
      update_cache()
    else
      fetch_from_cache(@history_key)
    end
    |> Enum.filter(&(&1.secondary_coin == secondary_coin?))
  end

  def cache_name, do: @cache_name

  def data_key, do: @history_key

  def updated_at_key, do: @last_update_key

  def recent_days_count, do: @recent_days

  defp cache_expired?(key) do
    cache_period = Application.get_env(:explorer, __MODULE__)[:cache_period]
    updated_at = fetch_from_cache(key)

    cond do
      is_nil(updated_at) -> true
      Helper.current_time() - updated_at > cache_period -> true
      true -> false
    end
  end

  defp update_cache do
    new_data = fetch_from_db()

    put_into_cache(@last_update_key, Helper.current_time())
    put_into_cache(@history_key, new_data)

    new_data
  end

  defp fetch_from_db do
    day_diff = @recent_days * -1

    query =
      from(
        mh in MarketHistory,
        where: mh.date > date_add(^Date.utc_today(), ^day_diff, "day"),
        order_by: [desc: mh.date]
      )

    Repo.all(query)
  end

  defp fetch_from_cache(key) do
    ConCache.get(@cache_name, key)
  end

  defp put_into_cache(key, value) do
    ConCache.put(@cache_name, key, value)
  end
end
