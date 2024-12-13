defmodule Explorer.Chain.Fetcher.AddressesBlacklist do
  @moduledoc """
    Fetcher for addresses blacklist
  """
  alias Explorer.Chain

  use GenServer

  @keys_to_blacklist ["OFAC", "Malicious"]
  @cache_name :addresses_blacklist

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
    Process.send_after(self(), :fetch, retry_timeout())
    {:noreply, state}
  end

  defp run_fetch_task do
    Task.Supervisor.async_nolink(Explorer.GenesisDataTaskSupervisor, fn ->
      fetch_addresses_blacklist()
      |> MapSet.to_list()
      |> save_in_ets_cache()
    end)
  end

  defp fetch_addresses_blacklist do
    case HTTPoison.get(url()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Jason.decode()
        |> parse_blacklist()

      _ ->
        MapSet.new()
    end
  end

  defp parse_blacklist({:ok, json}) when is_map(json) do
    @keys_to_blacklist
    |> Enum.reduce([], fn key, acc ->
      acc ++
        (json
         |> Map.get(key, [])
         |> Enum.map(fn address_hash_string ->
           address_hash_or_nil = Chain.string_to_address_hash_or_nil(address_hash_string)
           address_hash_or_nil && {address_hash_or_nil, nil}
         end)
         |> Enum.reject(&is_nil/1))
    end)
    |> MapSet.new()
  end

  defp parse_blacklist({:error, _}) do
    MapSet.new()
  end

  defp save_in_ets_cache(blacklist) do
    :ets.delete_all_objects(@cache_name)
    :ets.insert(@cache_name, blacklist)
  end

  defp config do
    Application.get_env(:explorer, Explorer.Chain.Fetcher.AddressesBlacklist)
  end

  @spec url() :: any()
  defp url do
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

  @spec retry_timeout() :: any()
  defp retry_timeout do
    config()[:retry_timeout]
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
