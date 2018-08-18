defmodule Explorer.Token.BalanceReader do
  @moduledoc """
  Reads Token's balances using Smart Contract functions from the blockchain.
  """

  alias Explorer.SmartContract.Reader

  @balance_function_abi [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{
          "type" => "uint256",
          "name" => "balance"
        }
      ],
      "name" => "balanceOf",
      "inputs" => [
        %{
          "type" => "address",
          "name" => "tokenOwner"
        }
      ],
      "constant" => true
    }
  ]

  @doc """
  Fetches the token balances that were fetched without error and have balances more than 0.

  TODO: Remove this function once AddressTokenBalanceController is fetching balances from database.
  """
  def fetch_token_balances_without_error(tokens, address_hash_string) do
    tokens
    |> fetch_token_balances_from_blockchain(address_hash_string)
    |> Stream.filter(&token_without_error?/1)
    |> Stream.map(&format_result/1)
    |> Enum.filter(&tokens_with_no_zero_balance?/1)
  end

  defp token_without_error?({:ok, _token}), do: true
  defp token_without_error?({:error, _token}), do: false
  defp format_result({:ok, token}), do: token
  defp tokens_with_no_zero_balance?(%{balance: balance}), do: balance != 0

  @doc """
  Fetches the token balances given the tokens and the address hash as string.

  This function is going to perform one request async for each token inside a list of tokens in
  order to fetch the balance.
  """
  @spec fetch_token_balances_from_blockchain([], String.t()) :: []
  def fetch_token_balances_from_blockchain(tokens, address_hash_string) do
    tokens
    |> Task.async_stream(&fetch_from_blockchain(&1, address_hash_string))
    |> Enum.map(&format_blockchain_result_from_tasks/1)
  end

  defp fetch_from_blockchain(%{contract_address_hash: address_hash} = token, address_hash_string) do
    address_hash
    |> Reader.query_unverified_contract(@balance_function_abi, %{"balanceOf" => [address_hash_string]})
    |> format_blockchain_result(token)
  end

  defp format_blockchain_result(%{"balanceOf" => {:ok, [balance]}}, token) do
    {:ok, Map.put(token, :balance, balance)}
  end

  defp format_blockchain_result(%{"balanceOf" => {:error, error}}, token) do
    {:error, Map.put(token, :balance, error)}
  end

  defp format_blockchain_result_from_tasks({:ok, blockchain_result}), do: blockchain_result

  @spec get_balance_of(String.t(), String.t(), non_neg_integer()) :: {atom(), non_neg_integer() | String.t()}
  def get_balance_of(token_contract_address_hash, address_hash, block_number) do
    result =
      Reader.query_contract(
        token_contract_address_hash,
        @balance_function_abi,
        %{
          "balanceOf" => [address_hash]
        },
        block_number: block_number
      )

    format_balance_result(result)
  end

  defp format_balance_result(%{"balanceOf" => {:ok, [balance]}}) do
    {:ok, balance}
  end

  defp format_balance_result(%{"balanceOf" => {:error, error_message}}) do
    {:error, error_message}
  end
end
