defmodule Explorer.Chain.Cache.AddressesTabsCounters do
  @moduledoc """
    Cache for tabs counters on address
  """

  use GenServer

  import Explorer.Counters.Helper, only: [fetch_from_cache: 3]

  alias Explorer.Chain.Address.Counters

  @cache_name :addresses_tabs_counters

  @typep counter_type :: :validations | :txs | :token_transfers | :token_balances | :logs | :withdrawals | :internal_txs
  @typep response_status :: :limit_value | :stale | :up_to_date

  @spec get_counter(counter_type, String.t()) :: {DateTime.t(), non_neg_integer(), response_status} | nil
  def get_counter(counter_type, address_hash) do
    address_hash |> cache_key(counter_type) |> fetch_from_cache(@cache_name, nil) |> check_staleness()
  end

  @spec set_counter(counter_type, String.t(), non_neg_integer()) :: :ok
  def set_counter(counter_type, address_hash, counter, need_to_modify_state? \\ true) do
    :ets.insert(@cache_name, {cache_key(address_hash, counter_type), {DateTime.utc_now(), counter}})
    if need_to_modify_state?, do: ignore_txs(counter_type, address_hash)

    :ok
  end

  @spec set_task(atom, String.t()) :: true
  def set_task(counter_type, address_hash) do
    :ets.insert(@cache_name, {task_cache_key(address_hash, counter_type), true})
  end

  @spec drop_task(atom, String.t()) :: true
  def drop_task(counter_type, address_hash) do
    :ets.delete(@cache_name, task_cache_key(address_hash, counter_type))
  end

  @spec get_task(atom, String.t()) :: true | nil
  def get_task(counter_type, address_hash) do
    address_hash |> task_cache_key(counter_type) |> fetch_from_cache(@cache_name, nil)
  end

  @spec ignore_txs(atom, String.t()) :: :ignore | :ok
  def ignore_txs(:txs, address_hash), do: GenServer.cast(__MODULE__, {:ignore_txs, address_hash})
  def ignore_txs(_counter_type, _address_hash), do: :ignore

  def save_txs_counter_progress(address_hash, results) do
    GenServer.cast(__MODULE__, {:set_txs_state, address_hash, results})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(@cache_name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end

  @impl true
  def handle_cast({:ignore_txs, address_hash}, state) do
    {:noreply, Map.put(state, lowercased_string(address_hash), {:updated, DateTime.utc_now()})}
  end

  @impl true
  def handle_cast({:set_txs_state, address_hash, %{txs_types: txs_types} = results}, state) do
    address_hash = lowercased_string(address_hash)

    if is_ignored?(state[address_hash]) do
      {:noreply, state}
    else
      address_state =
        txs_types
        |> Enum.reduce(state[address_hash] || %{}, fn tx_type, acc ->
          Map.put(acc, tx_type, results[tx_type])
        end)
        |> (&Map.put(&1, :txs_types, (txs_types ++ (&1[:txs_types] || [])) |> Enum.uniq())).()

      counter =
        Counters.txs_types()
        |> Enum.reduce([], fn type, acc ->
          (address_state[type] || []) ++ acc
        end)
        |> Enum.uniq()
        |> Enum.count()
        |> min(Counters.counters_limit())

      if counter == Counters.counters_limit() || Enum.count(address_state[:txs_types]) == 3 do
        set_counter(:txs, address_hash, counter, false)
        {:noreply, Map.put(state, address_hash, {:updated, DateTime.utc_now()})}
      else
        {:noreply, Map.put(state, address_hash, address_state)}
      end
    end
  end

  defp is_ignored?({:updated, datetime}), do: is_up_to_date?(datetime, ttl())
  defp is_ignored?(_), do: false

  defp check_staleness(nil), do: nil
  defp check_staleness({datetime, counter}) when counter > 50, do: {datetime, counter, :limit_value}

  defp check_staleness({datetime, counter}) do
    status =
      if is_up_to_date?(datetime, ttl()) do
        :up_to_date
      else
        :stale
      end

    {datetime, counter, status}
  end

  defp is_up_to_date?(datetime, ttl) do
    datetime
    |> DateTime.add(ttl, :millisecond)
    |> DateTime.compare(DateTime.utc_now()) != :lt
  end

  defp ttl, do: Application.get_env(:explorer, Explorer.Chain.Cache.AddressesTabsCounters)[:ttl]
  defp lowercased_string(str), do: str |> to_string() |> String.downcase()

  defp cache_key(address_hash, counter_type), do: {lowercased_string(address_hash), counter_type}
  defp task_cache_key(address_hash, counter_type), do: {:task, lowercased_string(address_hash), counter_type}
end
