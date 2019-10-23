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

  @cryptokitties_address_hash "0x06012c8cf97bead5deae237070f9587f8e7a266d"

  @no_uri_error "no uri"

  def fetch_metadata(unquote(@cryptokitties_address_hash), token_id) do
    %{"tokenURI" => {:ok, ["https://api.cryptokitties.co/kitties/#{token_id}"]}}
    |> fetch_json()
  end

  def fetch_metadata(contract_address_hash, token_id) do
    contract_functions = %{"tokenURI" => [token_id]}

    contract_address_hash
    |> query_contract(contract_functions)
    |> fetch_json()
  end

  def query_contract(contract_address_hash, contract_functions) do
    Reader.query_contract(contract_address_hash, @abi, contract_functions)
  end

  defp fetch_json(%{"tokenURI" => {:ok, [""]}}) do
    {:ok, %{error: @no_uri_error}}
  end

  defp fetch_json(%{"tokenURI" => {:error, "(-32015) VM execution error."}}) do
    {:ok, %{error: @no_uri_error}}
  end

  defp fetch_json(%{"tokenURI" => {:ok, ["http://" <> _ = token_uri]}}) do
    fetch_metadata(token_uri)
  end

  defp fetch_json(%{"tokenURI" => {:ok, ["https://" <> _ = token_uri]}}) do
    fetch_metadata(token_uri)
  end

  defp fetch_json(%{"tokenURI" => {:ok, [json]}}) do
    Jason.decode(json)
  rescue
    e ->
      Logger.error(fn -> ["Unknown metadata format #{inspect(json)}. error #{inspect(e)}"] end)

      {:error, json}
  end

  defp fetch_json(result) do
    Logger.error(fn -> ["Unknown metadata format #{inspect(result)}."] end)

    {:error, result}
  end

  defp fetch_metadata(token_uri) do
    case HTTPoison.get(token_uri) do
      {:ok, %Response{body: body, status_code: 200}} ->
        {:ok, json} = Jason.decode(body)

        {:ok, %{metadata: json}}

      {:ok, %Response{body: body}} ->
        {:error, body}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  rescue
    e ->
      Logger.error(fn -> ["Could not send request to token uri #{inspect(token_uri)}. error #{inspect(e)}"] end)

      {:error, :request_error}
  end
end
