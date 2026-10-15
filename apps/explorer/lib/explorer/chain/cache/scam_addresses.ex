# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.ScamAddresses do
  @moduledoc """
  Keeps the set of addresses carrying a scam badge in an ETS table.

  `Explorer.Chain.Address.Reputation` needs nothing but a membership test, and
  `scam_address_badge_mappings` changes only through the admin badge endpoints,
  so the whole set fits in memory and the per-preload replica query becomes an
  ETS lookup.

  The table is reloaded on an interval and whenever a badge is assigned or
  revoked. Both happen in this process, one at a time, so a reload can never
  install a set that predates the change that triggered it.

  That holds within an instance. A badge change reloads the cache of the instance
  that served the admin request and of no other, so `:update_interval` is also the
  window in which instances can disagree about a badge — lower it where that
  matters. Nothing propagates the change sooner: libcluster runs only in the
  separate `:api` and `:indexer` modes, and the chain event sender is in-process
  in `:all` mode, so neither transport reaches every deployment topology.

  The cache is authoritative only once it has been loaded. Until the first
  reload succeeds — and whenever the process is not running at all — reads fall
  through to the database, so a disabled or not yet warmed up cache behaves
  exactly as if it did not exist. That fallback is also what bounds the cache:
  holding the whole table in memory pays off only while the table is small, and
  past `:max_size` rows the reload — a full scan on every instance, every
  interval — costs more than the queries it saves, so an oversized table is not
  cached at all.

  On every interval the process also chooses how token transfer lists hide scam
  tokens, see `token_transfers_filter/0`.
  """

  use GenServer

  require Logger

  import Ecto.Query, only: [from: 2, select: 3, where: 3]

  alias Explorer.Chain.Address.ScamBadgeToAddress
  alias Explorer.Chain.Cache.Counters.Helper, as: CountersHelper
  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Repo

  @table_name "scam_address_badge_mappings"

  @cache_name :scam_addresses

  # Tells a loaded table apart from an empty one. Cached keys are `Hash.Address`
  # structs, so an atom can never collide with one.
  @loaded_key :__loaded__

  # The filter lives apart from the addresses: a reload empties the address
  # table, and a request reading the filter at that moment would get the
  # anti-join on a chain where it is the slow choice.
  @filter_table :scam_addresses_token_transfers_filter

  # 0.5 is the share PostgreSQL assumes for the NOT EXISTS filter. The anti-join
  # is kept while its own estimate is the more realistic one, and the gap around
  # 0.5 keeps a chain close to it from switching back and forth as statistics
  # drift.
  @switch_to_not_exists_below 0.4
  @switch_to_anti_join_above 0.6

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  @spec init(any()) :: {:ok, nil}
  def init(_) do
    :ets.new(@cache_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true
    ])

    :ets.new(@filter_table, [
      :set,
      :named_table,
      :protected,
      read_concurrency: true
    ])

    send(self(), :reload)

    {:ok, nil}
  end

  @impl true
  def handle_info(:reload, state) do
    load()
    choose_token_transfers_filter()
    Process.send_after(self(), :reload, update_interval())

    {:noreply, state}
  end

  @impl true
  def handle_call(:reload, _from, state) do
    load()

    {:reply, :ok, state}
  end

  @doc """
  Returns the subset of `address_hashes` that carry a scam badge.
  """
  @spec scam_hashes([Hash.Address.t()]) :: MapSet.t(Hash.Address.t())
  def scam_hashes([]), do: MapSet.new()

  def scam_hashes(address_hashes) do
    if loaded?() do
      for address_hash <- address_hashes,
          :ets.member(@cache_name, address_hash),
          into: MapSet.new(),
          do: address_hash
    else
      db_scam_hashes(address_hashes)
    end
  end

  @doc """
  Checks whether the given address carries a scam badge.
  """
  @spec scam?(Hash.Address.t()) :: boolean()
  def scam?(address_hash) do
    [address_hash] |> scam_hashes() |> MapSet.member?(address_hash)
  end

  @doc """
  Returns the form in which `Explorer.Helper.maybe_hide_scam_addresses_for_token_transfers/2`
  hides scam tokens: `:anti_join` or `:not_exists`.

  Both columns of the anti-join are primary keys, so PostgreSQL has no
  most-common-value statistics for it and estimates it from distinct counts
  alone. Once there are at least as many scam addresses as tokens, it assumes
  that every token is a scam one. A token transfer list is then estimated at a
  single row and planned as a sort of every transfer of every token. The
  NOT EXISTS filter is planned with a fixed 0.5 selectivity instead, so it is
  chosen when PostgreSQL expects fewer than #{round(@switch_to_not_exists_below * 100)}%
  of tokens to survive the anti-join, and dropped again above
  #{round(@switch_to_anti_join_above * 100)}%. Everywhere else the anti-join stays: it
  keeps hashing and parallel plans available to queries that read everything.

  Until the first estimate, and whenever the process is not running, the filter
  is the anti-join.
  """
  @spec token_transfers_filter() :: :anti_join | :not_exists
  def token_transfers_filter do
    case :ets.lookup(@filter_table, :filter) do
      [{:filter, filter}] -> filter
      [] -> :anti_join
    end
  rescue
    # The table goes away with the process.
    ArgumentError -> :anti_join
  end

  @doc """
  Reloads the cache, so that a badge just assigned or revoked shows up without
  waiting for the next interval.
  """
  @spec reload() :: :ok
  def reload do
    GenServer.call(__MODULE__, :reload)
  catch
    # The cache is not running — disabled, or on its way down — and the reads it
    # would have served already fall through to the database.
    :exit, _ -> :ok
  end

  defp load do
    entries = if oversized?(), do: :oversized, else: fetch_entries()

    :ets.delete_all_objects(@cache_name)

    # An oversized table is left without the marker, which is what sends reads to
    # the database rather than letting an empty table report every address clean.
    case entries do
      :oversized -> :ok
      entries -> :ets.insert(@cache_name, [{@loaded_key} | entries])
    end

    :ok
  rescue
    error ->
      # Reads fall back to the database until the next interval. Letting this
      # crash would take the table down with the process and restart it in a loop
      # for as long as the database is unreachable.
      Logger.error("Failed to load the scam addresses cache: #{inspect(error)}")

      :ok
  end

  defp fetch_entries do
    ScamBadgeToAddress
    |> select([badge], {badge.address_hash})
    |> Repo.replica().all()
  end

  # A `reltuples` estimate rather than a `count/0`: this guard exists to keep the
  # reload cheap, so it cannot start with a full scan of its own. A table
  # PostgreSQL has no statistics for reports `nil` and is let through — a table
  # that new is not the one the guard is here for.
  defp oversized? do
    max_size = max_size()
    estimated_size = CountersHelper.estimated_count_from(@table_name, api?: true)

    if estimated_size && estimated_size > max_size do
      Logger.warning(
        "Scam addresses cache is not used: #{@table_name} is estimated at #{estimated_size} rows, over the limit of #{max_size}. " <>
          "Scam badge lookups fall back to the database. Raise CACHE_SCAM_ADDRESSES_MAX_SIZE to cache the table anyway."
      )

      true
    else
      false
    end
  end

  defp loaded? do
    :ets.whereis(@cache_name) != :undefined and :ets.member(@cache_name, @loaded_key)
  end

  defp db_scam_hashes(address_hashes) do
    ScamBadgeToAddress
    |> where([badge], badge.address_hash in ^address_hashes)
    |> select([badge], badge.address_hash)
    |> Repo.replica().all()
    |> MapSet.new()
  end

  defp choose_token_transfers_filter do
    current = token_transfers_filter()
    share = non_scam_tokens_share()
    chosen = next_token_transfers_filter(current, share)

    if chosen != current, do: log_token_transfers_filter(chosen, share)

    :ets.insert(@filter_table, {:filter, chosen})

    :ok
  rescue
    error ->
      # The previous choice holds until the next interval.
      Logger.error("Failed to choose the scam filter for token transfer lists: #{inspect(error)}")

      :ok
  end

  defp next_token_transfers_filter(:anti_join, share) when is_number(share) and share < @switch_to_not_exists_below,
    do: :not_exists

  defp next_token_transfers_filter(:not_exists, share) when is_number(share) and share > @switch_to_anti_join_above,
    do: :anti_join

  defp next_token_transfers_filter(current, _share), do: current

  # The share of tokens PostgreSQL expects to survive the anti-join with the
  # badges: its row estimate for the anti-join over the one for the side the
  # anti-join keeps. Only planned, never executed.
  defp non_scam_tokens_share do
    query =
      from(token in Token,
        as: :token,
        where:
          not exists(
            from(badge in ScamBadgeToAddress,
              where: badge.address_hash == parent_as(:token).contract_address_hash,
              select: 1
            )
          ),
        select: 1
      )

    [%{"Plan" => plan}] = Repo.replica().explain(:all, query, format: :map)

    case find_anti_join(plan) do
      %{"Plan Rows" => rows, "Join Type" => join_type, "Plans" => children} ->
        # A right anti-join (PostgreSQL 16+) keeps the side it hashes, which is
        # its second child; a plain one keeps the outer side.
        kept = if join_type == "Right Anti", do: Enum.at(children, 1), else: hd(children)
        rows / max(kept["Plan Rows"], 1)

      nil ->
        nil
    end
  end

  defp find_anti_join(%{"Join Type" => type} = node) when type in ["Anti", "Right Anti"], do: node
  defp find_anti_join(%{"Plans" => [first | _]}), do: find_anti_join(first)
  defp find_anti_join(_), do: nil

  defp log_token_transfers_filter(:not_exists, share) do
    Logger.warning(
      "Token transfer lists hide scam tokens with NOT EXISTS: PostgreSQL estimates that only #{percent(share)} of tokens " <>
        "have no scam badge, which would plan them as a sort of every transfer."
    )
  end

  defp log_token_transfers_filter(:anti_join, share) do
    Logger.info(
      "Token transfer lists hide scam tokens with an anti-join again: PostgreSQL estimates that #{percent(share)} of tokens have no scam badge."
    )
  end

  defp percent(share), do: "#{Float.round(share * 100, 1)}%"

  defp config do
    Application.get_env(:explorer, __MODULE__)
  end

  defp update_interval do
    config()[:update_interval]
  end

  defp max_size do
    config()[:max_size]
  end
end
