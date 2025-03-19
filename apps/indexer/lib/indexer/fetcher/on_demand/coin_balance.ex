defmodule Indexer.Fetcher.OnDemand.CoinBalance do
  @moduledoc """
  Ensures that we have a reasonably up to date coin balance for a given address.

  If we have an unfetched coin balance for that address, it will be synchronously fetched.
  If not we will fetch the coin balance and created a fetched coin balance.
  If we have a fetched coin balance, but it is over 100 blocks old, we will fetch and create a fetched coin balance.
  """

  use Indexer.Fetcher, restart: :permanent

  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias EthereumJSONRPC.FetchedBalances
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.Address.{CoinBalance, CoinBalanceDaily}
  alias Explorer.Chain.Cache.{Accounts, BlockNumber}
  alias Explorer.Counters.AverageBlockTime
  alias Indexer.BufferedTask
  alias Indexer.Fetcher.CoinBalance.Helper, as: CoinBalanceHelper
  alias Timex.Duration

  @behaviour BufferedTask

  @max_batch_size 500
  @max_concurrency 4
  @defaults [
    flush_interval: :timer.seconds(3),
    max_concurrency: @max_concurrency,
    max_batch_size: @max_batch_size,
    task_supervisor: Indexer.Fetcher.OnDemand.CoinBalance.TaskSupervisor,
    metadata: [fetcher: :coin_balance_on_demand]
  ]

  @type block_number :: integer

  @typedoc """
  `block_number` represents the block that we will be updating the address to.

  If there is a pending balance in the window, we will not fetch the balance
  as of the latest block, we will instead fetch that pending balance.
  """
  @type balance_status ::
          :current
          | {:stale, block_number}
          | {:pending, block_number}

  @spec trigger_fetch(Address.t()) :: balance_status
  def trigger_fetch(address) do
    if __MODULE__.Supervisor.disabled?() do
      :current
    else
      latest_block_number = latest_block_number()

      case stale_balance_window(latest_block_number) do
        {:error, _} ->
          :current

        stale_balance_window ->
          do_trigger_fetch(address, latest_block_number, stale_balance_window)
      end
    end
  end

  @spec trigger_historic_fetch(Hash.Address.t(), non_neg_integer()) :: balance_status
  def trigger_historic_fetch(address_hash, block_number) do
    if __MODULE__.Supervisor.disabled?() do
      :current
    else
      do_trigger_historic_fetch(address_hash, block_number)
    end
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    {state, mergeable_init_options} = Keyword.pop(init_options, :json_rpc_named_arguments)

    unless state do
      raise ArgumentError,
            ":json_rpc_named_arguments must be provided to `#{__MODULE__}.child_spec " <>
              "to allow for json_rpc calls when running."
    end

    merged_init_opts =
      @defaults
      |> Keyword.merge(mergeable_init_options)
      |> Keyword.put(:state, state)

    Supervisor.child_spec({BufferedTask, [{__MODULE__, merged_init_opts}, gen_server_options]}, id: __MODULE__)
  end

  @impl BufferedTask
  def init(initial, _, _) do
    initial
  end

  @impl BufferedTask
  def run(entries, json_rpc_named_arguments) do
    {fetch_and_update_params, fetch_and_import_params, daily_params} =
      Enum.reduce(entries, {[], [], []}, fn
        {:fetch_and_update, block_number, address}, {acc, other_1, other_2} ->
          {[{block_number, address} | acc], other_1, other_2}

        {:fetch_and_import, block_number, address}, {other_1, acc, other_2} ->
          {other_1, [{block_number, address} | acc], other_2}

        {:fetch_and_import_daily_balances, block_number, address}, {other_1, other_2, acc} ->
          {other_1, other_2, [{block_number, address} | acc]}
      end)

    fetch_and_update(fetch_and_update_params, json_rpc_named_arguments)
    fetch_and_import(fetch_and_import_params, json_rpc_named_arguments)
    fetch_and_import_daily_balances(daily_params, json_rpc_named_arguments)

    :ok
  end

  defp fetch_and_update([], _json_rpc_named_arguments), do: :ok

  defp fetch_and_update(params, json_rpc_named_arguments) do
    with {:ok, %{params_list: params_list}} when params_list != [] <- fetch_balances(params, json_rpc_named_arguments),
         address_params = CoinBalanceHelper.balances_params_to_address_params(params_list),
         {:ok, %{addresses: addresses}} <-
           Chain.import(%{
             addresses: %{params: address_params, with: :balance_changeset},
             broadcast: :on_demand
           }) do
      Accounts.drop(addresses)
    else
      _ -> :ok
    end
  end

  defp fetch_and_import([], _json_rpc_named_arguments), do: :ok

  defp fetch_and_import(params, json_rpc_named_arguments) do
    case fetch_balances(params, json_rpc_named_arguments) do
      {:ok, fetched_balances} -> do_import(fetched_balances)
      _ -> :ok
    end
  end

  defp fetch_and_import_daily_balances([], _json_rpc_named_arguments), do: :ok

  defp fetch_and_import_daily_balances(params, json_rpc_named_arguments) do
    case fetch_balances(params, json_rpc_named_arguments) do
      {:ok, fetched_balances} -> do_import_daily_balances(fetched_balances)
      _ -> :ok
    end
  end

  defp do_trigger_fetch(%Address{fetched_coin_balance_block_number: nil} = address, latest_block_number, _) do
    BufferedTask.buffer(__MODULE__, [{:fetch_and_update, latest_block_number, address}], false)

    {:stale, 0}
  end

  defp do_trigger_fetch(address, latest_block_number, stale_balance_window) do
    latest_by_day = CoinBalanceDaily.latest_by_day_query(address.hash)

    latest = CoinBalance.latest_coin_balance_query(address.hash, stale_balance_window)

    do_trigger_balance_fetch_query(address, latest_block_number, stale_balance_window, latest, latest_by_day)
  end

  defp do_trigger_historic_fetch(address_hash, block_number) do
    BufferedTask.buffer(__MODULE__, [{:fetch_and_import, block_number, %{hash: address_hash}}], false)

    {:stale, 0}
  end

  defp do_trigger_balance_fetch_query(
         address,
         latest_block_number,
         stale_balance_window,
         query_balances,
         query_balances_daily
       ) do
    if address.fetched_coin_balance_block_number < stale_balance_window do
      do_trigger_balance_daily_fetch_query(address, latest_block_number, query_balances_daily)
      BufferedTask.buffer(__MODULE__, [{:fetch_and_update, latest_block_number, address}], false)

      {:stale, latest_block_number}
    else
      case Repo.one(query_balances) do
        nil ->
          # There is no recent coin balance to fetch, so we check to see how old the
          # balance is on the address. If it is too old, we check again, just to be safe.
          do_trigger_balance_daily_fetch_query(address, latest_block_number, query_balances_daily)

          :current

        %CoinBalance{value_fetched_at: nil, block_number: block_number} ->
          BufferedTask.buffer(__MODULE__, [{:fetch_and_import, block_number, address}], false)

          {:pending, block_number}

        %CoinBalance{} ->
          do_trigger_balance_daily_fetch_query(address, latest_block_number, query_balances_daily)

          :current
      end
    end
  end

  defp do_trigger_balance_daily_fetch_query(address, latest_block_number, query) do
    if Repo.one(query) == nil do
      BufferedTask.buffer(__MODULE__, [{:fetch_and_import_daily_balances, latest_block_number, address}], false)
    end
  end

  defp fetch_balances(params, json_rpc_named_arguments) do
    params
    |> Enum.map(fn {block_number, address} ->
      %{block_quantity: integer_to_quantity(block_number), hash_data: to_string(address.hash)}
    end)
    |> EthereumJSONRPC.fetch_balances(json_rpc_named_arguments, latest_block_number())
  end

  defp do_import(%FetchedBalances{} = fetched_balances) do
    case CoinBalanceHelper.import_fetched_balances(fetched_balances, :on_demand) do
      {:ok, %{addresses: [address]}} -> {:ok, address}
      _ -> :error
    end
  end

  defp do_import_daily_balances(%FetchedBalances{} = fetched_balances) do
    case CoinBalanceHelper.import_fetched_daily_balances(fetched_balances, :on_demand) do
      {:ok, %{addresses: [address]}} -> {:ok, address}
      _ -> :error
    end
  end

  defp latest_block_number do
    BlockNumber.get_max()
  end

  @spec stale_balance_window(non_neg_integer()) :: non_neg_integer() | {:error, :empty_database}
  defp stale_balance_window(block_number) do
    case AverageBlockTime.average_block_time() do
      {:error, :disabled} ->
        fallback_threshold_in_blocks = Application.get_env(:indexer, __MODULE__)[:fallback_threshold_in_blocks]
        block_number - fallback_threshold_in_blocks

      duration ->
        average_block_time =
          duration
          |> Duration.to_milliseconds()
          |> round()

        if average_block_time == 0 do
          {:error, :empty_database}
        else
          threshold = Application.get_env(:indexer, __MODULE__)[:threshold]
          block_number - div(threshold, average_block_time)
        end
    end
  end
end
