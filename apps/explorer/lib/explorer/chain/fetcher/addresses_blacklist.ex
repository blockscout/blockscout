defmodule Explorer.Chain.Fetcher.AddressesBlacklist do
  @moduledoc """
  General fetcher for addresses blacklist
  """
  use GenServer

  @cache_name :addresses_blacklist

  @doc """
  Fetches the addresses blacklist.
  """
  @callback fetch_addresses_blacklist() :: MapSet.t()

  @impl true
  @spec init(any()) :: {:ok, nil}
  def init(_) do
    :ets.new(@cache_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true
    ])

    GenServer.cast(__MODULE__, :fetch)

    {:ok, nil}
  end

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def handle_cast(:fetch, state) do
    run_fetch_task()
    {:noreply, state}
  end

  @impl true
  def handle_info(:fetch, state) do
    run_fetch_task()
    {:noreply, state}
  end

  @impl true
  def handle_info({_ref, _result}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    Process.send_after(self(), :fetch, update_interval())
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    Process.send_after(self(), :fetch, retry_interval())
    {:noreply, state}
  end

  defp run_fetch_task do
    Task.Supervisor.async_nolink(Explorer.GenesisDataTaskSupervisor, fn ->
      select_provider_module().fetch_addresses_blacklist()
      |> MapSet.to_list()
      |> save_in_ets_cache()
    end)
  end

  defp save_in_ets_cache(blacklist) do
    :ets.delete_all_objects(@cache_name)
    :ets.insert(@cache_name, blacklist)
  end

  defp config do
    Application.get_env(:explorer, Explorer.Chain.Fetcher.AddressesBlacklist)
  end

  @spec url() :: any()
  def url do
    config()[:url]
  end

  @spec enabled?() :: any()
  defp enabled? do
    config()[:enabled]
  end

  @spec update_interval() :: any()
  defp update_interval do
    config()[:update_interval]
  end

  @spec retry_interval() :: any()
  defp retry_interval do
    config()[:retry_interval]
  end

  defp select_provider_module do
    case config()[:provider] do
      _ ->
        Explorer.Chain.Fetcher.AddressesBlacklist.Blockaid
    end
  end

  @doc """
  Checks if the given address is blacklisted.

  ## Parameters
  - `address_hash`: The address to check.

  ## Returns
  - `true` if the address is blacklisted.
  - `false` if the address is not blacklisted.
  """
  @spec blacklisted?(any()) :: boolean()
  def blacklisted?(address_hash) do
    enabled?() && :ets.member(@cache_name, address_hash)
  end
end
