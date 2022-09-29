defmodule Explorer.Token.InstanceOwnerReader do
  @moduledoc """
  Reads Token Instance owner using Smart Contract function from the blockchain.
  """

  require Logger

  alias Explorer.SmartContract.Reader

  @owner_function_signature "6352211e"

  @owner_function_abi [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{
          "type" => "address",
          "name" => "owner"
        }
      ],
      "name" => "ownerOf",
      "inputs" => [
        %{
          "type" => "uint256",
          "name" => "tokenId"
        }
      ]
    }
  ]

  @spec get_owner_of([%{token_contract_address_hash: String.t(), token_id: integer}]) :: [
          {:ok, String.t()} | {:error, String.t()}
        ]
  def get_owner_of(instance_owner_requests) do
    instance_owner_requests
    |> Enum.map(&format_owner_request/1)
    |> Reader.query_contracts(@owner_function_abi)
    |> Enum.zip(instance_owner_requests)
    |> Enum.reduce([], fn {result, request}, acc ->
      case format_owner_result(result, request) do
        {:ok, ok_result} ->
          [ok_result] ++ acc

        {:error, error_message} ->
          Logger.error(
            "Failed to get owner of token #{request.token_contract_address_hash}, token_id #{request.token_id}, reason: #{error_message}"
          )

          acc
      end
    end)
  end

  defp format_owner_request(%{token_contract_address_hash: token_contract_address_hash, token_id: token_id}) do
    %{
      contract_address: token_contract_address_hash,
      method_id: @owner_function_signature,
      args: [token_id]
    }
  end

  defp format_owner_result({:ok, [owner]}, request) do
    {:ok,
     %{
       token_contract_address_hash: request.token_contract_address_hash,
       token_id: request.token_id,
       owner: owner
     }}
  end

  defp format_owner_result({:error, error_message}, _request) do
    {:error, error_message}
  end
end
