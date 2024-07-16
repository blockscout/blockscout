defmodule Explorer.Chain.Cache.ShibariumCounter do
  @moduledoc """
  Caches the number of deposits and withdrawals for Shibarium Bridge.
  """

  alias Explorer.Chain

  @deposits_counter_type "shibarium_deposits_counter"
  @withdrawals_counter_type "shibarium_withdrawals_counter"

  @doc """
  Fetches the cached deposits count from the `last_fetched_counters` table.
  """
  def deposits_count(options \\ []) do
    Chain.get_last_fetched_counter(@deposits_counter_type, options)
  end

  @doc """
  Fetches the cached withdrawals count from the `last_fetched_counters` table.
  """
  def withdrawals_count(options \\ []) do
    Chain.get_last_fetched_counter(@withdrawals_counter_type, options)
  end

  @doc """
  Stores or increments the current deposits count in the `last_fetched_counters` table.
  """
  def deposits_count_save(count, just_increment \\ false) do
    if just_increment do
      Chain.increment_last_fetched_counter(
        @deposits_counter_type,
        count
      )
    else
      Chain.upsert_last_fetched_counter(%{
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
      Chain.increment_last_fetched_counter(
        @withdrawals_counter_type,
        count
      )
    else
      Chain.upsert_last_fetched_counter(%{
        counter_type: @withdrawals_counter_type,
        value: count
      })
    end
  end
end
