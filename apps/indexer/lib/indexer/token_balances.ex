defmodule Indexer.TokenBalances do
  @moduledoc """
  Reads Token's balances using Smart Contract functions from the blockchain.
  """

  require Logger

  alias Explorer.Chain
  alias Explorer.Token.BalanceReader
  alias Indexer.TokenBalance

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
  def fetch_token_balances_from_blockchain(token_balances) do
    fetched_token_balances =
      token_balances
      |> Task.async_stream(&fetch_token_balance/1, on_timeout: :kill_task)
      |> Stream.map(&format_task_results/1)
      |> Enum.filter(&ignore_request_with_timeouts/1)

    token_balances
    |> MapSet.new()
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

  defp schedule_token_balances(unfetched_token_balances) do
    unfetched_token_balances
    |> Enum.map(fn token_balance ->
      {:ok, address_hash} = Chain.string_to_address_hash(token_balance.address_hash)
      {:ok, token_hash} = Chain.string_to_address_hash(token_balance.token_contract_address_hash)

      %{address_hash: address_hash, token_contract_address_hash: token_hash, block_number: token_balance.block_number}
    end)
    |> TokenBalance.Fetcher.async_fetch()
  end

  def format_task_results({:exit, :timeout}), do: {:error, :timeout}
  def format_task_results({:ok, token_balance}), do: token_balance

  def ignore_request_with_timeouts({:error, :timeout}), do: false
  def ignore_request_with_timeouts(_token_balance), do: true

  def log_fetching_errors(from, token_balances_params) do
    error_messages =
      token_balances_params
      |> Stream.filter(fn token_balance -> token_balance.error != nil end)
      |> Enum.map(fn token_balance ->
        "<address_hash: #{token_balance.address_hash}, " <>
          "contract_address_hash: #{token_balance.token_contract_address_hash}, " <>
          "block_number: #{token_balance.block_number}, " <> "error: #{token_balance.error}> \n"
      end)

    if Enum.any?(error_messages) do
      Logger.debug(
        [
          "<#{from}> ",
          "Errors while fetching TokenBalances through Contract interaction: \n",
          error_messages
        ],
        fetcher: :token_balances
      )
    end
  end

  @doc """
  Finds the unfetched token balances given all token balances and the ones that were fetched.

  This function compares the two given lists using the `MapSet.difference/2` and return the difference.
  """
  def unfetched_token_balances(token_balances, fetched_token_balances) do
    fetched_token_balances_set =
      MapSet.new(fetched_token_balances, fn token_balance ->
        %{
          address_hash: token_balance.address_hash,
          token_contract_address_hash: token_balance.token_contract_address_hash,
          block_number: token_balance.block_number
        }
      end)

    MapSet.difference(token_balances, fetched_token_balances_set)
  end
end
