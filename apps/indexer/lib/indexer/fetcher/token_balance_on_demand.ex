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

  @spec trigger_historic_fetch(
          Hash.t(),
          Hash.t(),
          String.t(),
          Decimal.t() | nil,
          non_neg_integer()
        ) :: {:ok, pid}

  def trigger_historic_fetch(address_hash, contract_address_hash, token_type, token_id, block_number) do
    Task.start(fn ->
      do_trigger_historic_fetch(address_hash, contract_address_hash, token_type, token_id, block_number)
    end)
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
      |> Enum.map(fn {%{token_id: token_id} = stale_current_token_balance, token} ->
        stale_current_token_balances_to_fetch = [
          %{
            token_contract_address_hash: "0x" <> Base.encode16(token.contract_address_hash.bytes),
            address_hash: "0x" <> Base.encode16(address_hash.bytes),
            block_number: block_number,
            token_id: token_id && Decimal.to_integer(token_id)
          }
        ]

        balance_response =
          case stale_current_token_balance.token_type do
            "ERC-1155" -> BalanceReader.get_balances_of_erc_1155(stale_current_token_balances_to_fetch)
            _ -> BalanceReader.get_balances_of(stale_current_token_balances_to_fetch)
          end

        updated_balance = balance_response[:ok]

        if updated_balance do
          %{}
          |> Map.put(:address_hash, stale_current_token_balance.address_hash)
          |> Map.put(:token_contract_address_hash, token.contract_address_hash)
          |> Map.put(:token_type, token.type)
          |> Map.put(:token_id, token_id)
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

  defp do_trigger_historic_fetch(address_hash, contract_address_hash, token_type, token_id, block_number) do
    request = %{
      token_contract_address_hash: to_string(contract_address_hash),
      address_hash: to_string(address_hash),
      block_number: block_number,
      token_id: token_id && Decimal.to_integer(token_id)
    }

    balance_response =
      case token_type do
        "ERC-1155" -> BalanceReader.get_balances_of_erc_1155([request])
        _ -> BalanceReader.get_balances_of([request])
      end

    balance = balance_response[:ok]

    if balance do
      %{
        address_token_balances: %{
          params: [
            %{
              address_hash: address_hash,
              token_contract_address_hash: contract_address_hash,
              token_type: token_type,
              token_id: token_id,
              block_number: block_number,
              value: Decimal.new(balance),
              value_fetched_at: DateTime.utc_now()
            }
          ]
        },
        broadcast: :on_demand
      }
      |> Chain.import()
    end
  end

  defp latest_block_number do
    BlockNumber.get_max()
  end

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
