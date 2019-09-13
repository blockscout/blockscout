defmodule Explorer.Token.InstanceMetadataRetriever do
  @moduledoc """
  Fetches ERC721 token instance metadata.
  """

  require Logger

  alias Explorer.SmartContract.Reader
  alias HTTPoison.{Error, Response}

  @abi [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{"type" => "string", "name" => ""}
      ],
      "name" => "tokenURI",
      "inputs" => [
        %{
          "type" => "uint256",
          "name" => "_tokenId"
        }
      ],
      "constant" => true
    }
  ]

  def fetch_metadata(contract_address_hash, token_id) do
    contract_functions = %{"tokenURI" => [token_id]}

    contract_address_hash
    |> query_contract(contract_functions)
    |> fetch_json()
  end

  def query_contract(contract_address_hash, contract_functions) do
    Reader.query_contract(contract_address_hash, @abi, contract_functions)
  end

  defp fetch_json(%{"tokenURI" => {:ok, [token_uri]}}) do
    case HTTPoison.get(token_uri) do
      {:ok, %Response{body: body, status_code: 200}} ->
        data = Jason.decode(body)

        {:ok, data}

      {:ok, %Response{body: body}} ->
        {:error, body}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp fetch_json(result) do
    {:error, result}
  end
end
