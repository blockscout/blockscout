defmodule Indexer.TokenBalances do
  @moduledoc """
  Reads Token's balances using Smart Contract functions from the blockchain.
  """

  require Logger

  alias Explorer.Chain
  alias Explorer.Token.BalanceReader
  alias Indexer.TokenBalance

  # The timeout used for each process opened by Task.async_stream/3. Default 15s.
  @task_timeout 15000

  @doc """
  Fetches TokenBalances from specific Addresses and Blocks in the Blockchain

  Every `TokenBalance` is fetched asynchronously, but in case an exception is raised (such as a
  timeout) during the RPC call the particular TokenBalance request is ignored and sent to
  `TokenBalance.Fetcher` to be fetched again.

  ## token_balances

  It is a list of a Map so that each map must have:

  * `token_contract_address_hash` - The contract address that represents the Token in the blockchain.
  * `address_hash` - The address_hash that we want to know the balance.
  * `block_number` - The block number that the address_hash has the balance.
  """
  def fetch_token_balances_from_blockchain([]), do: {:ok, []}

  def fetch_token_balances_from_blockchain(token_balances, opts \\ []) do
    Logger.debug(fn -> "fetching #{Enum.count(token_balances)} token balances" end)

    task_timeout = Keyword.get(opts, :timeout, @task_timeout)

    requested_token_balances =
      token_balances
      |> Task.async_stream(&fetch_token_balance/1, timeout: task_timeout, on_timeout: :kill_task)
      |> Stream.map(&format_task_results/1)
      |> Enum.filter(&ignore_killed_task/1)

    fetched_token_balances = Enum.filter(requested_token_balances, &ignore_request_with_errors/1)

    requested_token_balances
    |> handle_killed_tasks(token_balances)
    |> unfetched_token_balances(fetched_token_balances)
    |> schedule_token_balances

    {:ok, fetched_token_balances}
  end

  defp fetch_token_balance(
         %{
           token_contract_address_hash: token_contract_address_hash,
           address_hash: address_hash,
           block_number: block_number
         } = token_balance
       ) do
    token_contract_address_hash
    |> BalanceReader.get_balance_of(address_hash, block_number)
    |> set_token_balance_value(token_balance)
  end

  defp set_token_balance_value({:ok, balance}, token_balance) do
    Map.merge(token_balance, %{value: balance, value_fetched_at: DateTime.utc_now(), error: nil})
  end

  defp set_token_balance_value({:error, error_message}, token_balance) do
    Map.merge(token_balance, %{value: nil, value_fetched_at: nil, error: error_message})
  end

  defp schedule_token_balances([]), do: nil

  defp schedule_token_balances(unfetched_token_balances) do
    Logger.debug(fn -> "#{Enum.count(unfetched_token_balances)} token balances will be retried" end)

    log_fetching_errors(unfetched_token_balances)

    unfetched_token_balances
    |> Enum.map(fn token_balance ->
      {:ok, address_hash} = Chain.string_to_address_hash(token_balance.address_hash)
      {:ok, token_hash} = Chain.string_to_address_hash(token_balance.token_contract_address_hash)

      Map.merge(token_balance, %{
        address_hash: address_hash,
        token_contract_address_hash: token_hash,
        block_number: token_balance.block_number
      })
    end)
    |> TokenBalance.Fetcher.async_fetch()
  end

  defp format_task_results({:exit, :timeout}), do: {:error, :timeout}
  defp format_task_results({:ok, token_balance}), do: token_balance

  defp ignore_killed_task({:error, :timeout}), do: false
  defp ignore_killed_task(_token_balance), do: true

  defp ignore_request_with_errors(%{value: nil, value_fetched_at: nil, error: _error}), do: false
  defp ignore_request_with_errors(_token_balance), do: true

  defp handle_killed_tasks(requested_token_balances, token_balances) do
    token_balances
    |> Enum.reject(&present?(requested_token_balances, &1))
    |> Enum.map(&Map.merge(&1, %{value: nil, value_fetched_at: nil, error: :timeout}))
  end

  def log_fetching_errors(token_balances_params) do
    error_messages =
      token_balances_params
      |> Stream.filter(fn token_balance -> token_balance.error != nil end)
      |> Enum.map(fn token_balance ->
        "<address_hash: #{token_balance.address_hash}, " <>
          "contract_address_hash: #{token_balance.token_contract_address_hash}, " <>
          "block_number: #{token_balance.block_number}, " <>
          "error: #{token_balance.error}>, " <> "retried: #{Map.get(token_balance, :retries_count, 1)} times\n"
      end)

    if Enum.any?(error_messages) do
      Logger.debug(
        [
          "Errors while fetching TokenBalances through Contract interaction: \n",
          error_messages
        ],
        fetcher: :token_balances
      )
    end
  end

  @doc """
  Finds the unfetched token balances given all token balances and the ones that were fetched.

  * token_balances - all token balances that were received in this module.
  * fetched_token_balances - only the token balances that were fetched without error from the Smart contract

  This function compares the two given lists and return the difference.
  """
  def unfetched_token_balances(token_balances, fetched_token_balances) do
    if Enum.count(token_balances) == Enum.count(fetched_token_balances) do
      []
    else
      Enum.reject(token_balances, &present?(fetched_token_balances, &1))
    end
  end

  defp present?(list, token_balance) do
    Enum.any?(list, fn item ->
      token_balance.address_hash == item.address_hash &&
        token_balance.token_contract_address_hash == item.token_contract_address_hash &&
        token_balance.block_number == item.block_number
    end)
  end
end
