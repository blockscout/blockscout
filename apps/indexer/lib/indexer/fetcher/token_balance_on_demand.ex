defmodule Indexer.Fetcher.TokenBalanceOnDemand do
  @moduledoc """
  Ensures that we have a reasonably up to date address tokens balance.

  """

  @latest_balance_stale_threshold :timer.hours(24)

  use GenServer
  use Indexer.Fetcher

  alias Explorer.Chain
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Token.BalanceReader
  alias Timex.Duration

  ## Interface

  @spec trigger_fetch(Hash.t(), [CurrentTokenBalance.t()]) :: :ok
  def trigger_fetch(address_hash, current_token_balances) do
    latest_block_number = latest_block_number()

    case stale_balance_window(latest_block_number) do
      {:error, _} ->
        :current

      stale_balance_window ->
        do_trigger_fetch(address_hash, current_token_balances, latest_block_number, stale_balance_window)
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

  def handle_cast({:fetch_and_update, block_number, address_hash, current_token_balances}, state) do
    fetch_and_update(block_number, address_hash, current_token_balances, state.json_rpc_named_arguments)

    {:noreply, state}
  end

  ## Implementation

  defp do_trigger_fetch(address_hash, current_token_balances, latest_block_number, stale_balance_window)
       when not is_nil(address_hash) do
    stale_current_token_balances =
      current_token_balances
      |> Enum.filter(fn current_token_balance -> current_token_balance.block_number < stale_balance_window end)

    if Enum.count(stale_current_token_balances) > 0 do
      GenServer.cast(__MODULE__, {:fetch_and_update, latest_block_number, address_hash, stale_current_token_balances})
    else
      :current
    end

    :ok
  end

  defp fetch_and_update(block_number, address_hash, stale_current_token_balances, _json_rpc_named_arguments) do
    current_token_balances_update_params =
      stale_current_token_balances
      |> Enum.map(fn stale_current_token_balance ->
        stale_current_token_balances_to_fetch = [
          %{
            token_contract_address_hash:
              "0x" <> Base.encode16(stale_current_token_balance.token_contract_address_hash.bytes),
            address_hash: "0x" <> Base.encode16(address_hash.bytes),
            block_number: block_number
          }
        ]

        updated_balance = BalanceReader.get_balances_of(stale_current_token_balances_to_fetch)[:ok]

        token_balance =
          %{}
          |> Map.put(:address_hash, stale_current_token_balance.address_hash)
          |> Map.put(:token_contract_address_hash, stale_current_token_balance.token_contract_address_hash)
          |> Map.put(:block_number, block_number)

        if updated_balance do
          token_balance
          |> Map.put(:value, Decimal.new(updated_balance))
          |> Map.put(:value_fetched_at, DateTime.utc_now())
        else
          token_balance
        end
      end)

    Chain.import(%{
      address_current_token_balances: %{
        params: current_token_balances_update_params
      },
      broadcast: :on_demand
    })
  end

  defp latest_block_number do
    BlockNumber.get_max()
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

        if average_block_time == 0 do
          {:error, :empty_database}
        else
          block_number - div(@latest_balance_stale_threshold, average_block_time)
        end
    end
  end
end
