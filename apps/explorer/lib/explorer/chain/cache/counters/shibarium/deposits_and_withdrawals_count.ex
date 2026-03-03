defmodule Explorer.Chain.Cache.Counters.Shibarium.DepositsAndWithdrawalsCount do
  @moduledoc """
  Caches the number of deposits and withdrawals for Shibarium Bridge.
  """

  alias Explorer.Chain.Cache.Counters.LastFetchedCounter

  @deposits_counter_type "shibarium_deposits_counter"
  @withdrawals_counter_type "shibarium_withdrawals_counter"

  @doc """
  Fetches the cached deposits count from the `last_fetched_counters` table.
  """
  def deposits_count(options \\ []) do
    LastFetchedCounter.get(@deposits_counter_type, options)
  end

  @doc """
  Fetches the cached withdrawals count from the `last_fetched_counters` table.
  """
  def withdrawals_count(options \\ []) do
    LastFetchedCounter.get(@withdrawals_counter_type, options)
  end

  @doc """
  Stores or increments the current deposits count in the `last_fetched_counters` table.
  """
  def deposits_count_save(count, just_increment \\ false) do
    if just_increment do
      LastFetchedCounter.increment(
        @deposits_counter_type,
        count
      )
    else
      LastFetchedCounter.upsert(%{
        counter_type: @deposits_counter_type,
        value: count
      })
    end
  end

  @doc """
  Stores or increments the current withdrawals count in the `last_fetched_counters` table.
  """
  def withdrawals_count_save(count, just_increment \\ false) do
    if just_increment do
      LastFetchedCounter.increment(
        @withdrawals_counter_type,
        count
      )
    else
      LastFetchedCounter.upsert(%{
        counter_type: @withdrawals_counter_type,
        value: count
      })
    end
  end
end
