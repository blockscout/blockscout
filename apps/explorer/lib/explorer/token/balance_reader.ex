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

  @spec get_balances_of([
          %{token_contract_address_hash: String.t(), address_hash: String.t(), block_number: non_neg_integer()}
        ]) :: [{:ok, non_neg_integer()} | {:error, String.t()}]
  def get_balances_of(token_balance_requests) do
    regular_balances =
      token_balance_requests
      |> Enum.map(&format_balance_request/1)
      |> Reader.query_contracts(@balance_function_abi)
      |> Enum.map(&format_balance_result/1)

    erc1155_balances =
      token_balance_requests
      |> Enum.filter(fn request ->
        request.token_type == "ERC-1155"
      end)
      |> Enum.map(fn %{
                       address_hash: address_hash,
                       block_number: block_number,
                       token_contract_address_hash: token_contract_address_hash,
                       token_id: token_id
                     } ->
        %{
          contract_address: token_contract_address_hash,
          function_name: "balanceOf",
          args: [address_hash, token_id],
          block_number: block_number
        }
      end)
      |> Reader.query_contracts(@erc1155_balance_function_abi)
      |> Enum.map(&format_balance_result/1)

    regular_balances ++ erc1155_balances
  end

  defp format_balance_request(%{
         address_hash: address_hash,
         block_number: block_number,
         token_contract_address_hash: token_contract_address_hash
       }) do
    %{
      contract_address: token_contract_address_hash,
      method_id: "70a08231",
      args: [address_hash],
      block_number: block_number
    }
  end

  defp format_balance_result({:ok, [balance]}) do
    {:ok, balance}
  end

  defp format_balance_result({:error, error_message}) do
    {:error, error_message}
  end
end
