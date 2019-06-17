defmodule Explorer.Market.MarketHistoryCache do
  @moduledoc """
  Caches recent market history.
  """

  import Ecto.Query, only: [:from]

  alias Explorer.Repo

  @cache_name :market_history
  @last_update_key :last_update
  @history_key :history
  # 6 hours
  @cache_period 1_000 * 60 * 60 * 6
  @recent_days 30

  def fetch do
    if current_time() - fetch_from_cache(@last_update_key) > @cache_period do
      fetch_from_cache(@history_key)
    else
      update_cache()
    end
  end

  def cache_name, do: @cache_name

  def data_key, do: @history_key

  defp update_cache do
    new_data = fetch_from_db()

    put_into_cache(@last_update_key, current_time())
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

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end
end
