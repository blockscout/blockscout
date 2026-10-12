# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.Counters.AddressesAggregates do
  @moduledoc """
  Cache for the global aggregates over the `addresses` table:

  - `:count` - the number of all addresses;
  - `:sum` - the sum of all positive `fetched_coin_balance`s;
  - `:sum_minus_burnt` - the same sum excluding the burn address.

  All three values are produced by a single scan of the `addresses` table. On
  large chains that scan takes a long time, so computing the count and the sums
  separately would multiply the cost. The values are refreshed together every
  `CACHE_ADDRESS_AGGREGATES_PERIOD` by an async task which also persists them in
  `Explorer.Chain.Cache.Counters.LastFetchedCounter`, so that after a restart the
  last known values are served until the first refresh completes.
  """

  use Explorer.Chain.MapCache,
    name: :addresses_aggregates,
    key: :count,
    key: :sum,
    key: :sum_minus_burnt,
    key: :async_task,
    global_ttl: :infinity,
    ttl_check_interval: :timer.seconds(1),
    callback: &async_task_on_deletion(&1)

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain
  alias Explorer.Chain.{Address, SmartContract}
  alias Explorer.Chain.Cache.Counters.Helper, as: CacheCountersHelper
  alias Explorer.Chain.Cache.Counters.LastFetchedCounter
  alias Explorer.Repo

  @count_cache_key "addresses_count"
  @sum_cache_key "addresses_coin_balance_sum"
  @sum_minus_burnt_cache_key "addresses_coin_balance_sum_minus_burnt"

  @management_variable "CACHE_ADDRESS_AGGREGATES_PERIOD"

  @typedoc """
  The aggregates computed by a single query over the `addresses` table.
  """
  @type aggregates :: %{
          count: non_neg_integer(),
          sum: Decimal.t(),
          sum_minus_burnt: Decimal.t()
        }

  @doc """
  Gets the number of all `t:Explorer.Chain.Address.t/0`s.

  When the value is not cached yet, the last persisted value is returned, or the
  `pg_class` estimate when nothing was persisted.
  """
  @spec get_addresses_count() :: non_neg_integer()
  def get_addresses_count do
    CacheCountersHelper.evaluate_count(@count_cache_key, get_count(), :estimated_addresses_count)
  end

  @doc """
  Computes all the aggregates with a single query and stores them in the cache
  and in `Explorer.Chain.Cache.Counters.LastFetchedCounter`.

  Called by the async task; exposed to allow synchronous refreshes (e.g. in tests).
  """
  @spec consolidate() :: aggregates()
  def consolidate do
    %{count: count, sum: sum, sum_minus_burnt: sum_minus_burnt} = aggregates = fetch_aggregates()

    LastFetchedCounter.upsert(%{counter_type: @count_cache_key, value: count})
    LastFetchedCounter.upsert(%{counter_type: @sum_cache_key, value: sum})
    LastFetchedCounter.upsert(%{counter_type: @sum_minus_burnt_cache_key, value: sum_minus_burnt})

    ttl = CacheCountersHelper.ttl(__MODULE__, @management_variable)

    set_count(%ConCache.Item{ttl: ttl, value: count})
    set_sum(%ConCache.Item{ttl: ttl, value: sum})
    set_sum_minus_burnt(%ConCache.Item{ttl: ttl, value: sum_minus_burnt})

    aggregates
  end

  @doc """
  Runs the single aggregating query over the `addresses` table.
  """
  @spec fetch_aggregates() :: aggregates()
  def fetch_aggregates do
    {:ok, burn_address_hash} = Chain.string_to_address_hash(SmartContract.burn_address_hash_string())

    query =
      from(
        address in Address,
        select: %{
          count: count(),
          sum:
            fragment(
              "COALESCE(SUM(?) FILTER (WHERE ?), 0)",
              address.fetched_coin_balance,
              address.fetched_coin_balance > ^0
            ),
          sum_minus_burnt:
            fragment(
              "COALESCE(SUM(?) FILTER (WHERE ? AND ?), 0)",
              address.fetched_coin_balance,
              address.fetched_coin_balance > ^0,
              address.hash != ^burn_address_hash
            )
        }
      )

    %{count: count, sum: sum, sum_minus_burnt: sum_minus_burnt} = Repo.replica().one!(query, timeout: :infinity)

    %{count: count, sum: Decimal.new(sum), sum_minus_burnt: Decimal.new(sum_minus_burnt)}
  end

  defp handle_fallback(:count) do
    # This will get the task PID if one exists, check if it's running and launch
    # a new task if task doesn't exist or it's not running.
    # See `handle_fallback(:async_task)` definition
    safe_get_async_task()

    {:return, nil}
  end

  defp handle_fallback(:sum) do
    safe_get_async_task()

    {:return, LastFetchedCounter.get(@sum_cache_key, api?: true)}
  end

  defp handle_fallback(:sum_minus_burnt) do
    safe_get_async_task()

    {:return, LastFetchedCounter.get(@sum_minus_burnt_cache_key, api?: true)}
  end

  defp handle_fallback(:async_task) do
    # If this gets called it means an async task was requested, but none exists
    # so a new one needs to be launched
    {:ok, task} =
      Task.start_link(fn ->
        try do
          consolidate()
        rescue
          e ->
            Logger.debug([
              "Couldn't update addresses aggregates: ",
              Exception.format(:error, e, __STACKTRACE__)
            ])
        end

        set_async_task(nil)
      end)

    {:update, task}
  end

  # By setting this as a `callback` an async task will be started each time one
  # of the aggregates expires (unless there is one already running). All of them
  # are set at once with the same TTL, so a single task refreshes them together.
  defp async_task_on_deletion({:delete, _, key}) when key in [:count, :sum, :sum_minus_burnt],
    do: safe_get_async_task()

  defp async_task_on_deletion(_data), do: nil
end
