defmodule Indexer.Fetcher.TokenInstance.MetadataRetriever do
  @moduledoc """
  Fetches ERC-721 & ERC-1155 token instance metadata.
  """

  require Logger

  alias Explorer.SmartContract.Reader
  alias HTTPoison.{Error, Response}

  @no_uri_error "no uri"
  @vm_execution_error "VM execution error"
  @ipfs_protocol "ipfs://"

  # https://eips.ethereum.org/EIPS/eip-1155#metadata
  @erc1155_token_id_placeholder "{id}"

  @max_error_length 255

  @ignored_hosts ["localhost", "127.0.0.1", "0.0.0.0", "", nil]

  defp ipfs_link do
    link =
      :indexer
      |> Application.get_env(:ipfs_gateway_url)
      |> String.trim_trailing("/")

    link <> "/"
  end

  def query_contract(contract_address_hash, contract_functions, abi) do
    Reader.query_contract(contract_address_hash, abi, contract_functions, false)
  end

  @doc """
    Fetch/parse metadata using smart-contract's response
  """
  @spec fetch_json(any, binary() | nil) :: {:error, binary} | {:error_code, any} | {:ok, %{metadata: any}}
  def fetch_json(uri, hex_token_id \\ nil)

  def fetch_json(uri, _hex_token_id) when uri in [{:ok, [""]}, {:ok, [""]}] do
    {:error, @no_uri_error}
  end

  def fetch_json(uri, hex_token_id) do
    fetch_json_from_uri(uri, hex_token_id)
  end

  defp fetch_json_from_uri({:error, error}, _hex_token_id) do
    error = to_string(error)

    if error =~ "execution reverted" or error =~ @vm_execution_error do
      {:error, @vm_execution_error}
    else
      Logger.debug(["Unknown metadata format error #{inspect(error)}."], fetcher: :token_instances)

      # truncate error since it will be stored in DB
      {:error, truncate_error(error)}
    end
  end

  # CIDv0 IPFS links # https://docs.ipfs.tech/concepts/content-addressing/#version-0-v0
  defp fetch_json_from_uri({:ok, ["Qm" <> _ = result]}, hex_token_id) do
    if String.length(result) == 46 do
      fetch_json_from_uri({:ok, [ipfs_link() <> result]}, hex_token_id)
    else
      Logger.debug(["Unknown metadata format result #{inspect(result)}."], fetcher: :token_instances)

      {:error, truncate_error(result)}
    end
  end

  defp fetch_json_from_uri({:ok, ["'" <> token_uri]}, hex_token_id) do
    token_uri = token_uri |> String.split("'") |> List.first()
    fetch_metadata_inner(token_uri, hex_token_id)
  end

  defp fetch_json_from_uri({:ok, ["http://" <> _ = token_uri]}, hex_token_id) do
    fetch_metadata_inner(token_uri, hex_token_id)
  end

  defp fetch_json_from_uri({:ok, ["https://" <> _ = token_uri]}, hex_token_id) do
    fetch_metadata_inner(token_uri, hex_token_id)
  end

  defp fetch_json_from_uri({:ok, ["data:application/json," <> json]}, hex_token_id) do
    decoded_json = URI.decode(json)

    fetch_json_from_uri({:ok, [decoded_json]}, hex_token_id)
  rescue
    e ->
      Logger.debug(["Unknown metadata format #{inspect(json)}.", Exception.format(:error, e, __STACKTRACE__)],
        fetcher: :token_instances
      )

      {:error, "invalid data:application/json"}
  end

  defp fetch_json_from_uri({:ok, ["data:application/json;base64," <> base64_encoded_json]}, hex_token_id) do
    case Base.decode64(base64_encoded_json) do
      {:ok, base64_decoded} ->
        fetch_json_from_uri({:ok, [base64_decoded]}, hex_token_id)

      _ ->
        {:error, "invalid data:application/json;base64"}
    end
  rescue
    e ->
      Logger.debug(
        [
          "Unknown metadata format base64 #{inspect(base64_encoded_json)}.",
          Exception.format(:error, e, __STACKTRACE__)
        ],
        fetcher: :token_instances
      )

      {:error, "invalid data:application/json;base64"}
  end

  defp fetch_json_from_uri({:ok, ["#{@ipfs_protocol}ipfs/" <> right]}, hex_token_id) do
    fetch_from_ipfs(right, hex_token_id)
  end

  defp fetch_json_from_uri({:ok, ["ipfs/" <> right]}, hex_token_id) do
    fetch_from_ipfs(right, hex_token_id)
  end

  defp fetch_json_from_uri({:ok, [@ipfs_protocol <> right]}, hex_token_id) do
    fetch_from_ipfs(right, hex_token_id)
  end

  defp fetch_json_from_uri({:ok, [json]}, hex_token_id) do
    {:ok, json} = decode_json(json)

    check_type(json, hex_token_id)
  rescue
    e ->
      Logger.debug(["Unknown metadata format #{inspect(json)}.", Exception.format(:error, e, __STACKTRACE__)],
        fetcher: :token_instances
      )

      {:error, "invalid json"}
  end

  defp fetch_json_from_uri(uri, _hex_token_id) do
    Logger.debug(["Unknown metadata uri format #{inspect(uri)}."], fetcher: :token_instances)

    {:error, "unknown metadata uri format"}
  end

  defp fetch_from_ipfs(ipfs_uid, hex_token_id) do
    ipfs_url = ipfs_link() <> ipfs_uid
    fetch_metadata_inner(ipfs_url, hex_token_id)
  end

  defp fetch_metadata_inner(uri, hex_token_id) do
    prepared_uri = substitute_token_id_to_token_uri(uri, hex_token_id)
    fetch_metadata_from_uri(prepared_uri, hex_token_id)
  rescue
    e ->
      Logger.debug(
        ["Could not prepare token uri #{inspect(uri)}.", Exception.format(:error, e, __STACKTRACE__)],
        fetcher: :token_instances
      )

      {:error, "preparation error"}
  end

  def fetch_metadata_from_uri(uri, hex_token_id \\ nil) do
    case Mix.env() != :test && URI.parse(uri) do
      %URI{host: host} when host in @ignored_hosts ->
        {:error, "ignored host #{host}"}

      _ ->
        fetch_metadata_from_uri_inner(uri, hex_token_id)
    end
  end

  def fetch_metadata_from_uri_inner(uri, hex_token_id) do
    case Application.get_env(:explorer, :http_adapter).get(uri, [],
           recv_timeout: 30_000,
           follow_redirect: true,
           hackney: [pool: :token_instance_fetcher]
         ) do
      {:ok, %Response{body: body, status_code: 200, headers: headers}} ->
        content_type = get_content_type_from_headers(headers)

        check_content_type(content_type, uri, hex_token_id, body)

      {:ok, %Response{body: body, status_code: code}} ->
        Logger.debug(
          ["Request to token uri: #{inspect(uri)} failed with code #{code}. Body:", inspect(body)],
          fetcher: :token_instances
        )

        {:error_code, code}

      {:error, %Error{reason: reason}} ->
        Logger.debug(
          ["Request to token uri failed: #{inspect(uri)}.", inspect(reason)],
          fetcher: :token_instances
        )

        {:error, reason |> inspect() |> truncate_error()}
    end
  rescue
    e ->
      Logger.debug(
        ["Could not send request to token uri #{inspect(uri)}.", Exception.format(:error, e, __STACKTRACE__)],
        fetcher: :token_instances
      )

      {:error, "request error"}
  end

  defp check_content_type(content_type, uri, hex_token_id, body) do
    image = is_image?(content_type)
    video = is_video?(content_type)

    if content_type && (image || video) do
      json = if image, do: %{"image" => uri}, else: %{"animation_url" => uri}

      check_type(json, nil)
    else
      {:ok, json} = decode_json(body)

      check_type(json, hex_token_id)
    end
  end

  defp get_content_type_from_headers(headers) do
    {_, content_type} =
      Enum.find(headers, fn {header_name, _header_value} ->
        header_name == "Content-Type"
      end) || {nil, nil}

    content_type
  end

  defp is_image?(content_type) do
    content_type && String.starts_with?(content_type, "image/")
  end

  defp is_video?(content_type) do
    content_type && String.starts_with?(content_type, "video/")
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

  defp check_type(json, nil) when is_map(json) do
    {:ok, %{metadata: json}}
  end

  defp check_type(json, hex_token_id) when is_map(json) do
    metadata =
      case json
           |> Jason.encode!()
           |> String.replace(@erc1155_token_id_placeholder, hex_token_id)
           |> Jason.decode() do
        {:ok, map} ->
          map

        _ ->
          json
      end

    {:ok, %{metadata: metadata}}
  end

  defp check_type(_, _) do
    {:error, "wrong metadata type"}
  end

  defp substitute_token_id_to_token_uri(token_uri, empty_token_id) when empty_token_id in [nil, ""], do: token_uri

  defp substitute_token_id_to_token_uri(token_uri, hex_token_id) do
    String.replace(token_uri, @erc1155_token_id_placeholder, hex_token_id)
  end

  @doc """
    Truncate error string to @max_error_length symbols
  """
  @spec truncate_error(binary()) :: binary()
  def truncate_error(error), do: String.slice(error, 0, @max_error_length)
end
