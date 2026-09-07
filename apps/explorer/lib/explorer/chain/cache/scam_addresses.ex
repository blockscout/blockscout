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
  """

  use GenServer

  require Logger

  import Ecto.Query, only: [select: 3, where: 3]

  alias Explorer.Chain.Address.ScamBadgeToAddress
  alias Explorer.Chain.Cache.Counters.Helper, as: CountersHelper
  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @table_name "scam_address_badge_mappings"

  @cache_name :scam_addresses

  # Tells a loaded table apart from an empty one. Cached keys are `Hash.Address`
  # structs, so an atom can never collide with one.
  @loaded_key :__loaded__

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

    send(self(), :reload)

    {:ok, nil}
  end

  @impl true
  def handle_info(:reload, state) do
    load()
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
          "Scam badge lookups fall back to the database. Raise SCAM_ADDRESSES_CACHE_MAX_SIZE to cache the table anyway."
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
