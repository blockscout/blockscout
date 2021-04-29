defmodule Indexer.TokenBalances do
  @moduledoc """
  Reads Token's balances using Smart Contract functions from the blockchain.
  """

  use Spandex.Decorators, tracer: Indexer.Tracer

  require Indexer.Tracer
  require Logger

  alias Explorer.Chain
  alias Explorer.Token.BalanceReader
  alias Indexer.Fetcher.TokenBalance
  alias Indexer.Tracer

  @erc1155_balance_function_abi [
    %{
      "constant" => true,
      "inputs" => [%{"name" => "_owner", "type" => "address"}, %{"name" => "_id", "type" => "uint256"}],
      "name" => "balanceOf",
      "outputs" => [%{"name" => "", "type" => "uint256"}],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @doc """
  Fetches TokenBalances from specific Addresses and Blocks in the Blockchain

  In case an exception is raised during the RPC call the particular TokenBalance request
  is ignored and sent to `TokenBalance` to be fetched again.

  ## token_balances

  It is a list of a Map so that each map must have:

  * `token_contract_address_hash` - The contract address that represents the Token in the blockchain.
  * `address_hash` - The address_hash that we want to know the balance.
  * `block_number` - The block number that the address_hash has the balance.
  * `token_type` - type of the token that balance belongs to
  * `token_id` - token id for ERC-1155 tokens
  """
  def fetch_token_balances_from_blockchain([]), do: {:ok, []}

  @decorate span(tracer: Tracer)
  def fetch_token_balances_from_blockchain(token_balances) do
    Logger.debug("fetching token balances", count: Enum.count(token_balances))

    regular_token_balances =
      token_balances
      |> Enum.filter(fn request ->
        if Map.has_key?(request, :token_type) do
          request.token_type !== "ERC-1155"
        else
          true
        end
      end)

    erc1155_token_balances =
      token_balances
      |> Enum.filter(fn request ->
        if Map.has_key?(request, :token_type) do
          request.token_type == "ERC-1155"
        else
          false
        end
      end)

    requested_regular_token_balances =
      regular_token_balances
      |> BalanceReader.get_balances_of()
      |> Stream.zip(token_balances)
      |> Enum.map(fn {result, token_balance} -> set_token_balance_value(result, token_balance) end)

    requested_erc1155_token_balances =
      erc1155_token_balances
      |> BalanceReader.get_balances_of_with_abi(@erc1155_balance_function_abi)
      |> Stream.zip(token_balances)
      |> Enum.map(fn {result, token_balance} -> set_token_balance_value(result, token_balance) end)

    requested_token_balances = requested_regular_token_balances ++ requested_erc1155_token_balances
    fetched_token_balances = Enum.filter(requested_token_balances, &ignore_request_with_errors/1)

    requested_token_balances
    |> handle_killed_tasks(token_balances)
    |> unfetched_token_balances(fetched_token_balances)
    |> schedule_token_balances

    {:ok, fetched_token_balances}
  end

  def to_address_current_token_balances(address_token_balances) when is_list(address_token_balances) do
    address_token_balances
    |> Enum.group_by(fn %{
                          address_hash: address_hash,
                          token_contract_address_hash: token_contract_address_hash,
                          token_id: token_id
                        } ->
      {address_hash, token_contract_address_hash, token_id}
    end)
    |> Enum.map(fn {_, grouped_address_token_balances} ->
      Enum.max_by(grouped_address_token_balances, fn %{block_number: block_number} -> block_number end)
    end)
    |> Enum.sort_by(&{&1.token_contract_address_hash, &1.token_id, &1.address_hash})
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
    |> TokenBalance.async_fetch()
  end

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
