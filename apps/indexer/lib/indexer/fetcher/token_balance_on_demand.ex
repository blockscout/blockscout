defmodule Indexer.Fetcher.TokenBalanceOnDemand do
  @moduledoc """
  Ensures that we have a reasonably up to date address tokens balance.

  """

  use Indexer.Fetcher

  alias Explorer.Chain
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Hash
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

  ## Implementation

  defp do_trigger_fetch(address_hash, current_token_balances, latest_block_number, stale_balance_window)
       when not is_nil(address_hash) do
    stale_current_token_balances =
      current_token_balances
      |> Enum.filter(fn {current_token_balance, _} -> current_token_balance.block_number < stale_balance_window end)

    if Enum.count(stale_current_token_balances) > 0 do
      fetch_and_update(latest_block_number, address_hash, stale_current_token_balances)
    else
      :current
    end

    :ok
  end

  defp fetch_and_update(block_number, address_hash, stale_current_token_balances) do
    current_token_balances_update_params =
      stale_current_token_balances
      |> Enum.map(fn {stale_current_token_balance, _} ->
        stale_current_token_balances_to_fetch = [
          %{
            token_contract_address_hash:
              "0x" <> Base.encode16(stale_current_token_balance.token_contract_address_hash.bytes),
            address_hash: "0x" <> Base.encode16(address_hash.bytes),
            block_number: block_number
          }
        ]

        balance_response = BalanceReader.get_balances_of(stale_current_token_balances_to_fetch)
        updated_balance = balance_response[:ok]

        if updated_balance do
          %{}
          |> Map.put(:address_hash, stale_current_token_balance.address_hash)
          |> Map.put(:token_contract_address_hash, stale_current_token_balance.token_contract_address_hash)
          |> Map.put(:token_type, stale_current_token_balance.token.type)
          |> Map.put(:block_number, block_number)
          |> Map.put(:value, Decimal.new(updated_balance))
          |> Map.put(:value_fetched_at, DateTime.utc_now())
        else
          nil
        end
      end)

    filtered_current_token_balances_update_params =
      current_token_balances_update_params
      |> Enum.filter(&(!is_nil(&1)))

    Chain.import(%{
      address_current_token_balances: %{
        params: filtered_current_token_balances_update_params
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
          block_number - div(:timer.minutes(Application.get_env(:indexer, __MODULE__)[:threshold]), average_block_time)
        end
    end
  end
end
