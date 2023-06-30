defmodule Explorer.Counters.AddressTokenUsdSum do
  @moduledoc """
  Caches Address tokens USD value.
  """
  use GenServer

  alias Explorer.Chain
  alias Explorer.Counters.Helper

  @cache_name :address_tokens_fiat_value
  @last_update_key "last_update"

  config = Application.compile_env(:explorer, Explorer.Counters.AddressTokenUsdSum)
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

  def fetch(address_hash_string, token_balances) do
    if cache_expired?(address_hash_string) do
      Task.start_link(fn ->
        update_cache(address_hash_string, token_balances)
      end)
    end

    fetch_from_cache("hash_#{address_hash_string}")
  end

  @spec address_tokens_fiat_sum([{Address.CurrentTokenBalance, Explorer.Chain.Token}]) :: Decimal.t()
  defp address_tokens_fiat_sum(token_balances) do
    token_balances
    |> Enum.reduce(Decimal.new(0), fn {token_balance, token}, acc ->
      if token_balance.value && token.fiat_value && token.decimals do
        Decimal.add(acc, Chain.balance_in_fiat(token_balance, token))
      else
        acc
      end
    end)
  end

  def cache_name, do: @cache_name

  defp cache_expired?(address_hash_string) do
    cache_period = Application.get_env(:explorer, __MODULE__)[:cache_period]
    updated_at = fetch_from_cache("hash_#{address_hash_string}_#{@last_update_key}")

    cond do
      is_nil(updated_at) -> true
      Helper.current_time() - updated_at > cache_period -> true
      true -> false
    end
  end

  defp update_cache(address_hash_string, token_balances) do
    put_into_cache("hash_#{address_hash_string}_#{@last_update_key}", Helper.current_time())
    new_data = address_tokens_fiat_sum(token_balances)
    put_into_cache("hash_#{address_hash_string}", new_data)
  end

  defp fetch_from_cache(key) do
    Helper.fetch_from_cache(key, @cache_name)
  end

  defp put_into_cache(key, value) do
    :ets.insert(@cache_name, {key, value})
  end

  defp create_cache_table do
    Helper.create_cache_table(@cache_name)
  end

  defp enable_consolidation?, do: @enable_consolidation
end
