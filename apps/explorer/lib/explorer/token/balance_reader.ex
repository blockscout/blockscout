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
