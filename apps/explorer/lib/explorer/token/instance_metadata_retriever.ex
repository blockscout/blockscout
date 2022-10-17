defmodule Explorer.Token.InstanceMetadataRetriever do
  @moduledoc """
  Fetches ERC721 token instance metadata.
  """

  require Logger

  alias Explorer.SmartContract.Reader
  alias HTTPoison.{Error, Response}

  @token_uri "c87b56dd"

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

  @uri "0e89341c"

  @abi_uri [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "payable" => false,
      "outputs" => [
        %{
          "type" => "string",
          "name" => "",
          "internalType" => "string"
        }
      ],
      "name" => "uri",
      "inputs" => [
        %{
          "type" => "uint256",
          "name" => "_id",
          "internalType" => "uint256"
        }
      ],
      "constant" => true
    }
  ]

  @cryptokitties_address_hash "0x06012c8cf97bead5deae237070f9587f8e7a266d"

  @no_uri_error "no uri"
  @vm_execution_error "VM execution error"

  def fetch_metadata(unquote(@cryptokitties_address_hash), token_id) do
    %{"tokenURI" => {:ok, ["https://api.cryptokitties.co/kitties/#{token_id}"]}}
    |> fetch_json()
  end

  def fetch_metadata(contract_address_hash, token_id) do
    # c87b56dd =  keccak256(tokenURI(uint256))
    contract_functions = %{@token_uri => [token_id]}

    res =
      contract_address_hash
      |> query_contract(contract_functions, @abi)
      |> fetch_json()

    if res == {:ok, %{error: @vm_execution_error}} do
      contract_functions_uri = %{@uri => [token_id]}

      contract_address_hash
      |> query_contract(contract_functions_uri, @abi_uri)
      |> fetch_json()
    else
      res
    end
  end

  def query_contract(contract_address_hash, contract_functions, abi) do
    Reader.query_contract(contract_address_hash, abi, contract_functions, false)
  end

  def fetch_json(uri) when uri in [%{@token_uri => {:ok, [""]}}, %{@uri => {:ok, [""]}}] do
    {:ok, %{error: @no_uri_error}}
  end

  def fetch_json(uri)
      when uri in [
             %{@token_uri => {:error, "(-32015) VM execution error."}},
             %{@uri => {:error, "(-32015) VM execution error."}}
           ] do
    {:ok, %{error: @vm_execution_error}}
  end

  def fetch_json(%{@token_uri => {:error, "(-32015) VM execution error." <> _}}) do
    {:ok, %{error: @vm_execution_error}}
  end

  def fetch_json(%{@uri => {:error, "(-32015) VM execution error." <> _}}) do
    {:ok, %{error: @vm_execution_error}}
  end

  def fetch_json(%{@token_uri => {:ok, ["http://" <> _ = token_uri]}}) do
    fetch_metadata(token_uri)
  end

  def fetch_json(%{@uri => {:ok, ["http://" <> _ = token_uri]}}) do
    fetch_metadata(token_uri)
  end

  def fetch_json(%{@token_uri => {:ok, ["https://" <> _ = token_uri]}}) do
    fetch_metadata(token_uri)
  end

  def fetch_json(%{@uri => {:ok, ["https://" <> _ = token_uri]}}) do
    fetch_metadata(token_uri)
  end

  def fetch_json(%{@token_uri => {:ok, ["data:application/json," <> json]}}) do
    decoded_json = URI.decode(json)

    fetch_json(%{@token_uri => {:ok, [decoded_json]}})
  rescue
    e ->
      Logger.debug(["Unknown metadata format #{inspect(json)}. error #{inspect(e)}"],
        fetcher: :token_instances
      )

      {:error, json}
  end

  def fetch_json(%{@uri => {:ok, ["data:application/json," <> json]}}) do
    decoded_json = URI.decode(json)

    fetch_json(%{@token_uri => {:ok, [decoded_json]}})
  rescue
    e ->
      Logger.debug(["Unknown metadata format #{inspect(json)}. error #{inspect(e)}"],
        fetcher: :token_instances
      )

      {:error, json}
  end

  def fetch_json(%{@token_uri => {:ok, ["ipfs://ipfs/" <> ipfs_uid]}}) do
    ipfs_url = "https://ipfs.io/ipfs/" <> ipfs_uid
    fetch_metadata(ipfs_url)
  end

  def fetch_json(%{@uri => {:ok, ["ipfs://ipfs/" <> ipfs_uid]}}) do
    ipfs_url = "https://ipfs.io/ipfs/" <> ipfs_uid
    fetch_metadata(ipfs_url)
  end

  def fetch_json(%{@token_uri => {:ok, ["ipfs://" <> ipfs_uid]}}) do
    ipfs_url = "https://ipfs.io/ipfs/" <> ipfs_uid
    fetch_metadata(ipfs_url)
  end

  def fetch_json(%{@uri => {:ok, ["ipfs://" <> ipfs_uid]}}) do
    ipfs_url = "https://ipfs.io/ipfs/" <> ipfs_uid
    fetch_metadata(ipfs_url)
  end

  def fetch_json(%{@token_uri => {:ok, [json]}}) do
    {:ok, json} = decode_json(json)

    check_type(json)
  rescue
    e ->
      Logger.debug(["Unknown metadata format #{inspect(json)}. error #{inspect(e)}"],
        fetcher: :token_instances
      )

      {:error, json}
  end

  def fetch_json(%{@uri => {:ok, [json]}}) do
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

  defp fetch_metadata(uri) do
    case HTTPoison.get(uri) do
      {:ok, %Response{body: body, status_code: 200, headers: headers}} ->
        if Enum.member?(headers, {"Content-Type", "image/png"}) do
          json = %{"image" => uri}

          check_type(json)
        else
          {:ok, json} = decode_json(body)

          check_type(json)
        end

      {:ok, %Response{body: body, status_code: 301}} ->
        {:ok, json} = decode_json(body)

        check_type(json)

      {:ok, %Response{body: body}} ->
        {:error, body}

      {:error, %Error{reason: reason}} ->
        {:error, reason}
    end
  rescue
    e ->
      Logger.info(["Could not send request to token uri #{inspect(uri)}. error #{inspect(e)}"],
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
