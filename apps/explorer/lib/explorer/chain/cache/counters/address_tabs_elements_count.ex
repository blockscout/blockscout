defmodule Explorer.Chain.Cache.Counters.AddressTabsElementsCount do
  @moduledoc """
    Cache for tabs counters on address
  """

  use GenServer

  import Explorer.Chain.Cache.Counters.Helper, only: [fetch_from_ets_cache: 3]

  alias Explorer.Chain.Address.Counters

  @cache_name :addresses_tabs_counters

  @typep counter_type ::
           :validations
           | :transactions
           | :token_transfers
           | :token_balances
           | :logs
           | :withdrawals
           | :internal_transactions
  @typep response_status :: :limit_value | :stale | :up_to_date

  @spec get_counter(counter_type, String.t()) :: {DateTime.t(), non_neg_integer(), response_status} | nil
  def get_counter(counter_type, address_hash) do
    @cache_name |> fetch_from_ets_cache(address_hash |> cache_key(counter_type), nil) |> check_staleness()
  end

  @spec set_counter(counter_type, String.t(), non_neg_integer()) :: :ok
  def set_counter(counter_type, address_hash, counter) do
    :ets.insert(@cache_name, {cache_key(address_hash, counter_type), {DateTime.utc_now(), counter}})

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
    @cache_name |> fetch_from_ets_cache(address_hash |> task_cache_key(counter_type), nil)
  end

  def save_transactions_counter_progress(address_hash, results) do
    GenServer.cast(__MODULE__, {:set_transactions_state, address_hash, results})
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
  def handle_cast({:set_transactions_state, address_hash, %{transactions_types: transactions_types} = results}, state) do
    address_hash = lowercased_string(address_hash)

    if ignored?(state[address_hash]) do
      {:noreply, state}
    else
      address_state =
        transactions_types
        |> Enum.reduce(state[address_hash] || %{}, fn transaction_type, acc ->
          Map.put(acc, transaction_type, results[transaction_type])
        end)
        |> (&Map.put(&1, :transactions_types, (transactions_types ++ (&1[:transactions_types] || [])) |> Enum.uniq())).()

      counter =
        Counters.transactions_types()
        |> Enum.reduce([], fn type, acc ->
          (address_state[type] || []) ++ acc
        end)
        |> Enum.uniq()
        |> Enum.count()
        |> min(Counters.counters_limit())

      cond do
        Enum.count(address_state[:transactions_types]) == 3 ->
          set_counter(:transactions, address_hash, counter)
          {:noreply, Map.put(state, address_hash, nil)}

        counter == Counters.counters_limit() ->
          set_counter(:transactions, address_hash, counter)
          {:noreply, Map.put(state, address_hash, :limit_value)}

        true ->
          {:noreply, Map.put(state, address_hash, address_state)}
      end
    end
  end

  defp ignored?(:limit_value), do: true
  defp ignored?(_), do: false

  defp check_staleness(nil), do: nil
  defp check_staleness({datetime, counter}) when counter > 50, do: {datetime, counter, :limit_value}

  defp check_staleness({datetime, counter}) do
    status =
      if up_to_date?(datetime, ttl()) do
        :up_to_date
      else
        :stale
      end

    {datetime, counter, status}
  end

  defp up_to_date?(datetime, ttl) do
    datetime
    |> DateTime.add(ttl, :millisecond)
    |> DateTime.compare(DateTime.utc_now()) != :lt
  end

  defp ttl, do: Application.get_env(:explorer, Explorer.Chain.Cache.Counters.AddressTabsElementsCount)[:ttl]
  defp lowercased_string(str), do: str |> to_string() |> String.downcase()

  defp cache_key(address_hash, counter_type), do: {lowercased_string(address_hash), counter_type}
  defp task_cache_key(address_hash, counter_type), do: {:task, lowercased_string(address_hash), counter_type}
end
