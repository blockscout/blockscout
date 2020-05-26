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

  def fetch_json(%{"tokenURI" => {:ok, [""]}}) do
    {:ok, %{error: @no_uri_error}}
  end

  def fetch_json(%{"tokenURI" => {:error, "(-32015) VM execution error."}}) do
    {:ok, %{error: @no_uri_error}}
  end

  def fetch_json(%{"tokenURI" => {:ok, ["http://" <> _ = token_uri]}}) do
    fetch_metadata(token_uri)
  end

  def fetch_json(%{"tokenURI" => {:ok, ["https://" <> _ = token_uri]}}) do
    fetch_metadata(token_uri)
  end

  def fetch_json(%{"tokenURI" => {:ok, ["data:application/json," <> json]}}) do
    decoded_json = URI.decode(json)

    fetch_json(%{"tokenURI" => {:ok, [decoded_json]}})
  rescue
    e ->
      Logger.debug(["Unknown metadata format #{inspect(json)}. error #{inspect(e)}"],
        fetcher: :token_instances
      )

      {:error, json}
  end

  def fetch_json(%{"tokenURI" => {:ok, [json]}}) do
    {:ok, json} = decode_json(json)

    check_type(json)
  rescue
    e ->
      Logger.debug(["Unknown metadata format #{inspect(json)}. error #{inspect(e)}"],
        fetcher: :token_instances
      )

      {:error, json}
  end

  def fetch_json(result) do
    Logger.debug(["Unknown metadata format #{inspect(result)}."], fetcher: :token_instances)

    {:error, result}
  end

  defp fetch_metadata(token_uri) do
    case HTTPoison.get(token_uri) do
      {:ok, %Response{body: body, status_code: 200, headers: headers}} ->
        if Enum.member?(headers, {"Content-Type", "image/png"}) do
          json = %{"image" => %{"type" => "image", "description" => token_uri}}

          check_type(json)
        else
          {:ok, json} = decode_json(body)

          check_type(json)
        end

      {:ok, %Response{body: body}} ->
        {:error, body}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  rescue
    e ->
      Logger.debug(["Could not send request to token uri #{inspect(token_uri)}. error #{inspect(e)}"],
        fetcher: :token_instances
      )

      {:error, :request_error}
  end

  defp decode_json(body) do
    if String.valid?(body) do
      Jason.decode(body)
    else
      body
      |> :unicode.characters_to_binary(:latin1)
      |> Jason.decode()
    end
  end

  defp check_type(json) when is_map(json) do
    {:ok, %{metadata: json}}
  end

  defp check_type(_) do
    {:error, :wrong_metadata_type}
  end
end
