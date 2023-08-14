defmodule Explorer.Counters.AddressTokenTransfersCounter do
  @moduledoc """
  Caches Address token transfers counter.
  """
  use GenServer

  alias Ecto.Changeset
  alias Explorer.Chain.Address.Counters
  alias Explorer.Counters.Helper
  alias Explorer.Repo

  @cache_name :address_token_transfers_counter
  @last_update_key "last_update"

  config = Application.compile_env(:explorer, __MODULE__)
  @enable_consolidation Keyword.get(config, :enable_consolidation)

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    create_cache_table()

    {:ok, %{consolidate?: enable_consolidation?()}, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, %{consolidate?: true} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_continue(:ok, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:consolidate, state) do
    {:noreply, state}
  end

  def fetch(address) do
    if cache_expired?(address) do
      update_cache(address)
    end

    address_hash_string = to_string(address.hash)
    fetch_from_cache("hash_#{address_hash_string}")
  end

  def cache_name, do: @cache_name

  defp cache_expired?(address) do
    cache_period = Application.get_env(:explorer, __MODULE__)[:cache_period]
    address_hash_string = to_string(address.hash)
    updated_at = fetch_from_cache("hash_#{address_hash_string}_#{@last_update_key}")

    cond do
      is_nil(updated_at) -> true
      Helper.current_time() - updated_at > cache_period -> true
      true -> false
    end
  end

  defp update_cache(address) do
    address_hash_string = to_string(address.hash)
    put_into_cache("hash_#{address_hash_string}_#{@last_update_key}", Helper.current_time())
    new_data = Counters.address_to_token_transfer_count(address)
    put_into_cache("hash_#{address_hash_string}", new_data)
    put_into_db(address, new_data)
  end

  defp fetch_from_cache(key) do
    Helper.fetch_from_cache(key, @cache_name)
  end

  defp put_into_cache(key, value) do
    :ets.insert(@cache_name, {key, value})
  end

  defp put_into_db(address, value) do
    address
    |> Changeset.change(%{token_transfers_count: value})
    |> Repo.update()
  end

  defp create_cache_table do
    Helper.create_cache_table(@cache_name)
  end

  defp enable_consolidation?, do: @enable_consolidation
end
