defmodule Indexer.Fetcher.CoinBalanceOnDemand do
  @moduledoc """
  Ensures that we have a reasonably up to date coin balance for a given address.

  If we have an unfetched coin balance for that address, it will be synchronously fetched.
  If not we will fetch the coin balance and created a fetched coin balance.
  If we have a fetched coin balance, but it is over 100 blocks old, we will fetch and create a fetched coin baalnce.
  """

  @latest_balance_stale_threshold :timer.hours(24)

  use GenServer
  use Indexer.Fetcher

  import Ecto.Query, only: [from: 2]
  import EthereumJSONRPC, only: [integer_to_quantity: 1]

  alias EthereumJSONRPC.FetchedBalances
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, BlockNumberCache}
  alias Explorer.Chain.Address.CoinBalance
  alias Explorer.Counters.AverageBlockTime
  alias Indexer.Fetcher.CoinBalance, as: CoinBalanceFetcher
  alias Timex.Duration

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

  ## Interface

  @spec trigger_fetch(Address.t()) :: balance_status
  def trigger_fetch(address) do
    latest_block_number = latest_block_number()

    case stale_balance_window(latest_block_number) do
      {:error, :no_average_block_time} ->
        :current

      stale_balance_window ->
        do_trigger_fetch(address, latest_block_number, stale_balance_window)
    end
  end

  ## Callbacks

  def child_spec([json_rpc_named_arguments, server_opts]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [json_rpc_named_arguments, server_opts]},
      type: :worker
    }
  end

  def start_link(json_rpc_named_arguments, server_opts) do
    GenServer.start_link(__MODULE__, json_rpc_named_arguments, server_opts)
  end

  def init(json_rpc_named_arguments) do
    {:ok, %{json_rpc_named_arguments: json_rpc_named_arguments}}
  end

  def handle_cast({:fetch_and_update, block_number, address}, state) do
    fetch_and_update(block_number, address, state.json_rpc_named_arguments)

    {:noreply, state}
  end

  def handle_cast({:fetch_and_import, block_number, address}, state) do
    fetch_and_import(block_number, address, state.json_rpc_named_arguments)

    {:noreply, state}
  end

  ## Implementation

  defp do_trigger_fetch(%Address{fetched_coin_balance_block_number: nil} = address, latest_block_number, _) do
    GenServer.cast(__MODULE__, {:fetch_and_update, latest_block_number, address})

    {:stale, 0}
  end

  defp do_trigger_fetch(address, latest_block_number, stale_balance_window) do
    latest =
      from(
        cb in CoinBalance,
        where: cb.address_hash == ^address.hash,
        where: cb.block_number >= ^stale_balance_window,
        where: is_nil(cb.value_fetched_at),
        order_by: [desc: :block_number],
        limit: 1
      )

    if address.fetched_coin_balance_block_number < stale_balance_window do
      GenServer.cast(__MODULE__, {:fetch_and_update, latest_block_number, address})

      {:stale, latest_block_number}
    else
      case Repo.one(latest) do
        nil ->
          # There is no recent coin balance to fetch, so we check to see how old the
          # balance is on the address. If it is too old, we check again, just to be safe.
          :current

        %CoinBalance{value_fetched_at: nil, block_number: block_number} ->
          GenServer.cast(__MODULE__, {:fetch_and_import, block_number, address})

          {:pending, block_number}

        %CoinBalance{} ->
          :current
      end
    end
  end

  defp fetch_and_import(block_number, address, json_rpc_named_arguments) do
    case fetch_balances(block_number, address, json_rpc_named_arguments) do
      {:ok, fetched_balances} -> do_import(fetched_balances)
      _ -> :ok
    end
  end

  defp fetch_and_update(block_number, address, json_rpc_named_arguments) do
    case fetch_balances(block_number, address, json_rpc_named_arguments) do
      {:ok, %{params_list: []}} ->
        :ok

      {:ok, %{params_list: params_list}} ->
        address_params = CoinBalanceFetcher.balances_params_to_address_params(params_list)

        Chain.import(%{
          addresses: %{params: address_params, with: :balance_changeset},
          broadcast: :on_demand
        })

      _ ->
        :ok
    end
  end

  defp fetch_balances(block_number, address, json_rpc_named_arguments) do
    params = %{block_quantity: integer_to_quantity(block_number), hash_data: to_string(address.hash)}

    EthereumJSONRPC.fetch_balances([params], json_rpc_named_arguments)
  end

  defp do_import(%FetchedBalances{} = fetched_balances) do
    case CoinBalanceFetcher.import_fetched_balances(fetched_balances, :on_demand) do
      {:ok, %{addresses: [address]}} -> {:ok, address}
      _ -> :error
    end
  end

  defp latest_block_number do
    BlockNumberCache.max_number()
  end

  defp stale_balance_window(block_number) do
    case AverageBlockTime.average_block_time() do
      {:error, :disabled} ->
        {:error, :no_average_block_time}

      duration ->
        average_block_time =
          duration
          |> Duration.to_milliseconds()
          |> round()

        block_number - div(@latest_balance_stale_threshold, average_block_time)
    end
  end
end
