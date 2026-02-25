defmodule Explorer.Token.MetadataRetriever do
  @moduledoc """
  Reads Token's fields using Smart Contract functions from the blockchain.
  """

  require Logger

  alias Explorer.Chain.{Hash, Token}
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.{HttpClient, MetadataURIValidator}
  alias Explorer.SmartContract.Reader

  @no_uri_error "no uri"
  @vm_execution_error "VM execution error"
  @invalid_base64_data "invalid data:application/json;base64"
  @default_headers [{"User-Agent", "blockscout-10.0.1"}]

  # https://eips.ethereum.org/EIPS/eip-1155#metadata
  @erc1155_token_id_placeholder "{id}"

  @max_error_length 255

  # TODO: Consider using the `EthereumJSONRPC.ERC20` module to retrieve token metadata
  @contract_abi [
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "name",
      "outputs" => [
        %{
          "name" => "",
          "type" => "string"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "name",
      "outputs" => [
        %{"name" => "", "type" => "bytes32"}
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "decimals",
      "outputs" => [
        %{
          "name" => "",
          "type" => "uint8"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "totalSupply",
      "outputs" => [
        %{
          "name" => "",
          "type" => "uint256"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "symbol",
      "outputs" => [
        %{
          "name" => "",
          "type" => "string"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [],
      "name" => "symbol",
      "outputs" => [
        %{
          "name" => "",
          "type" => "bytes32"
        }
      ],
      "payable" => false,
      "type" => "function"
    },
    %{
      "name" => "contractURI",
      "type" => "function",
      "inputs" => [],
      "outputs" => [
        %{
          "name" => "",
          "type" => "string",
          "internalType" => "string"
        }
      ],
      "stateMutability" => "view"
    }
  ]

  # 313ce567 = keccak256(decimals())
  @decimals_signature "313ce567"
  # 06fdde03 = keccak256(name())
  @name_signature "06fdde03"
  # 95d89b41 = keccak256(symbol())
  @symbol_signature "95d89b41"
  # 18160ddd = keccak256(totalSupply())
  @total_supply_signature "18160ddd"
  @contract_functions %{
    @decimals_signature => [],
    @name_signature => [],
    @symbol_signature => [],
    @total_supply_signature => []
  }

  # e8a3d485 = keccak256(contractURI())
  @erc1155_contract_uri_signature "e8a3d485"
  @erc1155_contract_uri_function %{
    @erc1155_contract_uri_signature => []
  }

  @total_supply_function %{
    @total_supply_signature => []
  }

  @doc """
  Read functions below in the token's smart contract given the contract's address hash.

  * totalSupply
  * decimals
  * name
  * symbol

  if a token is of ERC-1155 type:

  * contractURI

  is added.

  This function will return a map with functions that were read in the Smart Contract, for instance:

  * Given that all functions were read:
  %{
    name: "BNT",
    decimals: 18,
    total_supply: 1_000_000_000_000_000_000,
    symbol: nil
  }

  * Given that some of them were read:
  %{
    name: "BNT",
    decimals: 18
  }

  It will retry to fetch each function in the Smart Contract according to :token_functions_reader_max_retries
  configured in the application env case one of them raised error.
  """
  @spec get_functions_of([Token.t()] | Token.t(), Keyword.t()) :: map() | {:ok, [map()]}
  def get_functions_of(tokens, opts \\ [])

  def get_functions_of(tokens, _opts) when is_list(tokens) do
    requests =
      tokens
      |> Enum.flat_map(fn token ->
        @contract_functions
        |> Enum.map(fn {method_id, args} ->
          %{contract_address: token.contract_address_hash, method_id: method_id, args: args}
        end)
      end)

    hashes = Enum.map(tokens, fn token -> token.contract_address_hash end)

    updated_at = DateTime.utc_now()

    fetched_result =
      requests
      |> Reader.query_contracts(@contract_abi)
      |> Enum.chunk_every(4)
      |> Enum.zip(hashes)
      |> Enum.map(fn {result, hash} ->
        formatted_result =
          [@name_signature, @total_supply_signature, @decimals_signature, @symbol_signature]
          |> Enum.zip(result)
          |> format_contract_functions_result(hash)

        formatted_result
        |> Map.put(:contract_address_hash, hash)
        |> Map.put(:updated_at, updated_at)
      end)

    erc_1155_tokens = tokens |> Enum.filter(fn token -> token.type == "ERC-1155" end)

    processed_result =
      if Enum.empty?(erc_1155_tokens) do
        fetched_result
      else
        fetched_result
        |> Enum.reduce([], fn token, acc ->
          # # credo:disable-for-lines:2
          updated_token =
            if Enum.any?(erc_1155_tokens, &(&1.contract_address_hash == token.contract_address_hash)) do
              try_to_fetch_erc_1155_name(token, token.contract_address_hash, "ERC-1155")
            else
              token
            end

          [updated_token | acc]
        end)
        |> Enum.reverse()
      end

    {:ok, processed_result}
  end

  def get_functions_of(%Token{contract_address_hash: contract_address_hash, type: type}, opts) do
    set_skip_metadata = Keyword.get(opts, :set_skip_metadata, false)

    raw_metadata =
      contract_address_hash
      |> fetch_functions_from_contract(@contract_functions)

    base_metadata =
      raw_metadata
      |> format_contract_functions_result(contract_address_hash)

    metadata = try_to_fetch_erc_1155_name(base_metadata, contract_address_hash, type)

    if Enum.empty?(metadata) && set_skip_metadata do
      Map.put(
        metadata,
        :skip_metadata,
        Enum.all?(raw_metadata, fn {_key, value} -> EthereumJSONRPC.contract_failure?(value) end)
      )
    else
      metadata
    end
  end

  defp try_to_fetch_erc_1155_name(base_metadata, contract_address_hash, token_type) do
    if token_type == "ERC-1155" && !Map.has_key?(base_metadata, :name) do
      erc_1155_name_uri =
        contract_address_hash
        |> fetch_functions_from_contract(@erc1155_contract_uri_function)
        |> format_contract_functions_result(contract_address_hash)

      case erc_1155_name_uri do
        %{:name => name} when is_binary(name) ->
          sanitized_name = String.trim(name)
          uri = {:ok, [sanitized_name]}

          with {:ok, %{metadata: metadata}} <- uri |> fetch_json(nil, nil, false) |> parse_fetch_json_response(),
               true <- Map.has_key?(metadata, "name"),
               false <- is_nil(metadata["name"]) do
            name_metadata = %{:name => metadata["name"]}

            Map.merge(base_metadata, name_metadata)
          else
            _ -> base_metadata
          end

        _ ->
          base_metadata
      end
    else
      base_metadata
    end
  end

  @doc """
  Parses the response from metadata fetching.

  ## Parameters
    - response: tuple containing either:
      - `{:ok_store_uri, metadata, uri}` - when metadata was successfully fetched and uri should be stored
      - `{:ok, result}` - when metadata was successfully fetched but not uri should be stored
      - `{:error, reason}` - when metadata fetch failed

  ## Returns
    - `{:ok, metadata}`
    - `{:error, reason}`

  ## Examples
      iex> parse_fetch_json_response({:ok_store_uri, %{name: "Token"}, "ipfs://..."})
      {:ok, %{name: "Token"}}

      iex> parse_fetch_json_response({:ok, %{name: "Token"}})
      {:ok, %{name: "Token"}}

      iex> parse_fetch_json_response({:error, "Failed to fetch"})
      {:error, "Failed to fetch"}
  """
  @spec parse_fetch_json_response({:ok | :error, any()} | {:ok_store_uri, any(), any()}) ::
          {:ok, any()} | {:error, any()}
  def parse_fetch_json_response({:ok_store_uri, metadata, _uri}) do
    {:ok, metadata}
  end

  def parse_fetch_json_response(other) do
    other
  end

  def get_total_supply_of(contract_address_hash) when is_binary(contract_address_hash) do
    contract_address_hash
    |> fetch_functions_from_contract(@total_supply_function)
    |> format_contract_functions_result(contract_address_hash)
  end

  defp fetch_functions_from_contract(contract_address_hash, contract_functions) do
    max_retries = Application.get_env(:explorer, :token_functions_reader_max_retries)

    fetch_functions_with_retries(contract_address_hash, contract_functions, %{}, max_retries)
  end

  defp fetch_functions_with_retries(_contract_address_hash, _contract_functions, accumulator, 0), do: accumulator

  defp fetch_functions_with_retries(contract_address_hash, contract_functions, accumulator, retries_left)
       when retries_left > 0 do
    contract_functions_result = Reader.query_contract(contract_address_hash, @contract_abi, contract_functions, false)

    functions_with_errors =
      Enum.filter(contract_functions_result, fn function ->
        case function do
          {_, {:error, _}} -> true
          {_, {:ok, _}} -> false
        end
      end)

    if Enum.any?(functions_with_errors) do
      log_functions_with_errors(contract_address_hash, functions_with_errors, retries_left)

      contract_functions_with_errors =
        Map.take(
          contract_functions,
          Enum.map(functions_with_errors, fn {function, _status} -> function end)
        )

      fetch_functions_with_retries(
        contract_address_hash,
        contract_functions_with_errors,
        Map.merge(accumulator, contract_functions_result),
        retries_left - 1
      )
    else
      fetch_functions_with_retries(
        contract_address_hash,
        %{},
        Map.merge(accumulator, contract_functions_result),
        0
      )
    end
  end

  defp log_functions_with_errors(contract_address_hash, functions_with_errors, retries_left) do
    error_messages =
      Enum.map(functions_with_errors, fn {function, {:error, error_message}} ->
        "function: #{function} - error: #{error_message} \n"
      end)

    Logger.debug(
      [
        "<Token contract hash: #{contract_address_hash}> error while fetching metadata: \n",
        error_messages,
        "Retries left: #{retries_left - 1}"
      ],
      fetcher: :token_functions
    )
  end

  defp format_contract_functions_result(contract_functions, contract_address_hash) do
    contract_functions =
      for {method_id, {:ok, [function_data]}} <- contract_functions, into: %{} do
        {atomized_key(method_id), function_data}
      end

    contract_functions
    |> handle_invalid_strings(contract_address_hash)
    |> handle_large_strings()
    |> limit_decimals()
  end

  defp atomized_key(@name_signature), do: :name
  defp atomized_key(@symbol_signature), do: :symbol
  defp atomized_key(@decimals_signature), do: :decimals
  defp atomized_key(@total_supply_signature), do: :total_supply
  defp atomized_key(@erc1155_contract_uri_signature), do: :name

  # It's a temp fix to store tokens that have names and/or symbols with characters that the database
  # doesn't accept. See https://github.com/blockscout/blockscout/issues/669 for more info.
  defp handle_invalid_strings(%{name: name, symbol: symbol} = contract_functions, contract_address_hash) do
    name = handle_invalid_name(name, contract_address_hash)
    symbol = handle_invalid_symbol(symbol)

    %{contract_functions | name: name, symbol: symbol}
  end

  defp handle_invalid_strings(%{name: name} = contract_functions, contract_address_hash) do
    name = handle_invalid_name(name, contract_address_hash)

    %{contract_functions | name: name}
  end

  defp handle_invalid_strings(%{symbol: symbol} = contract_functions, _contract_address_hash) do
    symbol = handle_invalid_symbol(symbol)

    %{contract_functions | symbol: symbol}
  end

  defp handle_invalid_strings(contract_functions, _contract_address_hash), do: contract_functions

  defp handle_invalid_name(nil, _contract_address_hash), do: nil

  defp handle_invalid_name(name, contract_address_hash) do
    case String.valid?(name) do
      true -> remove_null_bytes(name)
      false -> format_according_contract_address_hash(contract_address_hash)
    end
  end

  defp handle_invalid_symbol(symbol) do
    case String.valid?(symbol) do
      true -> remove_null_bytes(symbol)
      false -> nil
    end
  end

  @spec format_according_contract_address_hash(Hash.Address.t()) :: binary
  defp format_according_contract_address_hash(contract_address_hash) do
    contract_address_hash_string = Hash.to_string(contract_address_hash)
    String.slice(contract_address_hash_string, 0, 6)
  end

  defp handle_large_strings(%{name: name, symbol: symbol} = contract_functions) do
    [name, symbol] = Enum.map([name, symbol], &handle_large_string/1)

    %{contract_functions | name: name, symbol: symbol}
  end

  defp handle_large_strings(%{name: name} = contract_functions) do
    name = handle_large_string(name)

    %{contract_functions | name: name}
  end

  defp handle_large_strings(%{symbol: symbol} = contract_functions) do
    symbol = handle_large_string(symbol)

    %{contract_functions | symbol: symbol}
  end

  defp handle_large_strings(contract_functions), do: contract_functions

  defp handle_large_string(nil), do: nil
  defp handle_large_string(string), do: handle_large_string(string, byte_size(string))

  defp handle_large_string(string, size) when size > 255,
    do: string |> binary_part(0, 255) |> String.chunk(:valid) |> List.first()

  defp handle_large_string(string, _size), do: string

  defp limit_decimals(%{decimals: decimals} = contract_functions) do
    if decimals > 78 do
      %{contract_functions | decimals: nil}
    else
      contract_functions
    end
  end

  defp limit_decimals(contract_functions), do: contract_functions

  defp remove_null_bytes(string) do
    String.replace(string, "\0", "")
  end

  @doc """
  Generates an IPFS link for the given unique identifier (UID).

  ## Parameters

    - uid: The unique identifier for which the IPFS link is to be generated.
    - public_gateway?: A boolean indicating whether to use the public IPFS gateway.

  ## Returns

    - A string representing the IPFS link for the given UID.

  ## Examples

      iex> ipfs_link("QmTzQ1N1z5Q1N1z5Q1N1z5Q1N1z5Q1N1z5Q1N1z5", true)
      "https://ipfs.io/ipfs/QmTzQ1N1z5Q1N1z5Q1N1z5Q1N1z5Q1N1z5Q1N1z5"

      iex> ipfs_link("QmTzQ1N1z5Q1N1z5Q1N1z5Q1N1z5Q1N1z5Q1N1z5", false)
      "https://public_ipfs_gateway.io/QmTzQ1N1z5Q1N1z5Q1N1z5Q1N1z5Q1N1z5Q1N1z5"
  """
  @spec ipfs_link(uid :: any(), public_gateway? :: boolean) :: String.t()
  def ipfs_link(uid, public_gateway? \\ false) do
    key = if public_gateway?, do: :public_gateway_url, else: :gateway_url

    base_url =
      :indexer
      |> Application.get_env(:ipfs)
      |> Keyword.get(key)
      |> String.trim_trailing("/")

    url = "#{base_url}/#{uid}"

    url |> maybe_add_ipfs_gateway_params_to_url?(public_gateway?)
  end

  @doc """
  Generates an Arweave link for the given UID.

  ## Parameters
  - uid: The unique identifier for the resource.

  ## Returns
  - A string representing the full URL to the resource on Arweave.

  ## Examples

      iex> arweave_link("some-uid")
      "https://arweave.net/some-uid"

  """
  @spec arweave_link(uid :: any()) :: String.t()
  def arweave_link(uid) do
    "https://arweave.net/#{uid}"
  end

  defp maybe_add_ipfs_gateway_params_to_url?(url, true), do: url

  defp maybe_add_ipfs_gateway_params_to_url?(url, _) do
    ipfs_params = Application.get_env(:indexer, :ipfs)

    if ipfs_params[:gateway_url_param_location] == :query do
      gateway_url_param_key = ipfs_params[:gateway_url_param_key]
      gateway_url_param_value = ipfs_params[:gateway_url_param_value]

      if gateway_url_param_key && gateway_url_param_value do
        url <> "?#{gateway_url_param_key}=#{gateway_url_param_value}"
      else
        url
      end
    else
      url
    end
  end

  defp public_ipfs_link(uid) do
    "ipfs://" <> uid
  end

  @doc """
  Returns the headers required for making requests to IPFS.

  ## Examples

      iex> Explorer.Token.MetadataRetriever.ipfs_headers()
      [
        {"User-Agent", "blockscout-6.9.0"},
        {"Authorization", "Bearer <token>"}
      ]

  """
  @spec ipfs_headers() :: [{binary(), binary()}]
  def ipfs_headers do
    ipfs_params = Application.get_env(:indexer, :ipfs)

    if ipfs_params[:gateway_url_param_location] == :header do
      gateway_url_param_key = ipfs_params[:gateway_url_param_key]
      gateway_url_param_value = ipfs_params[:gateway_url_param_value]

      if gateway_url_param_key && gateway_url_param_value do
        [{gateway_url_param_key, gateway_url_param_value} | @default_headers]
      else
        @default_headers
      end
    else
      @default_headers
    end
  end

  @doc """
  Returns the headers for making requests to Arweave.

  ## Examples

      iex> Explorer.Token.MetadataRetriever.ar_headers()
      [
        {"User-Agent", "blockscout-6.9.0"}
      ]

  """
  @spec ar_headers() :: [{binary(), binary()}]
  def ar_headers do
    @default_headers
  end

  @doc """
    Fetch/parse metadata using smart-contract's response
  """
  @spec(
    fetch_json(any, integer() | nil, binary() | nil, boolean) ::
      {:error, binary} | {:error_code, any} | {:ok, %{metadata: any}},
    {:ok_store_uri, %{metadata: any}, binary()}
  )
  def fetch_json(uri, token_id \\ nil, hex_token_id \\ nil, from_base_uri? \\ false)

  def fetch_json({:ok, [""]}, _token_id, _hex_token_id, _from_base_uri?) do
    {:error, @no_uri_error}
  end

  def fetch_json(uri, token_id, hex_token_id, from_base_uri?) do
    fetch_json_from_uri(uri, [ipfs?: false], token_id, hex_token_id, from_base_uri?)
  end

  defp fetch_json_from_uri(_uri, _ipfs_params, _token_id, _hex_token_id, _from_base_uri?)

  defp fetch_json_from_uri({:error, error}, _ipfs_params, _token_id, _hex_token_id, _from_base_uri?) do
    error = to_string(error)

    if error =~ "execution reverted" or error =~ @vm_execution_error do
      {:error, @vm_execution_error}
    else
      Logger.warning(["Unknown metadata format error #{inspect(error)}."], fetcher: :token_instances)

      # truncate error since it will be stored in DB
      {:error, truncate_error(error)}
    end
  end

  defp fetch_json_from_uri({:ok, ["'" <> token_uri]}, ipfs_params, token_id, hex_token_id, from_base_uri?) do
    token_uri = token_uri |> String.split("'") |> List.first()
    fetch_metadata_inner(token_uri, ipfs_params, token_id, hex_token_id, from_base_uri?)
  end

  defp fetch_json_from_uri(
         {:ok, [type = "data:application/json;utf8," <> json]},
         ipfs_params,
         token_id,
         hex_token_id,
         from_base_uri?
       ) do
    fetch_json_from_json_string(json, ipfs_params, token_id, hex_token_id, from_base_uri?, type)
  end

  defp fetch_json_from_uri(
         {:ok, [type = "data:application/json," <> json]},
         ipfs_params,
         token_id,
         hex_token_id,
         from_base_uri?
       ) do
    fetch_json_from_json_string(json, ipfs_params, token_id, hex_token_id, from_base_uri?, type)
  end

  defp fetch_json_from_uri(
         {:ok, ["data:application/json;base64," <> base64_encoded_json]},
         ipfs_params,
         token_id,
         hex_token_id,
         from_base_uri?
       ) do
    case Base.decode64(base64_encoded_json) do
      {:ok, base64_decoded} ->
        fetch_json_from_uri({:ok, [base64_decoded]}, ipfs_params, token_id, hex_token_id, from_base_uri?)

      _ ->
        {:error, @invalid_base64_data}
    end
  rescue
    e ->
      Logger.warning(
        [
          "Unknown metadata format base64 #{inspect(base64_encoded_json)}.",
          Exception.format(:error, e, __STACKTRACE__)
        ],
        fetcher: :token_instances
      )

      {:error, @invalid_base64_data}
  end

  defp fetch_json_from_uri({:ok, [token_uri_string]}, ipfs_params, token_id, hex_token_id, from_base_uri?) do
    fetch_from_ipfs_or_ar?(token_uri_string, ipfs_params, token_id, hex_token_id, from_base_uri?)
  end

  defp fetch_json_from_uri(uri, _ipfs_params, _token_id, _hex_token_id, _from_base_uri?) do
    Logger.warning(["Unknown metadata uri format #{inspect(uri)}."], fetcher: :token_instances)

    {:error, "unknown metadata uri format"}
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp fetch_from_ipfs_or_ar?(token_uri_string, ipfs_params, token_id, hex_token_id, from_base_uri?) do
    case URI.parse(token_uri_string) do
      %URI{scheme: "ipfs", host: host, path: path} ->
        resource_id =
          if host == "ipfs" do
            "/" <> resource_id = path
            resource_id
          else
            # credo:disable-for-next-line
            if is_nil(path), do: host, else: host <> path
          end

        fetch_from_ipfs(resource_id, hex_token_id)

      %URI{scheme: "ar", host: _host, path: resource_id} ->
        fetch_from_arweave(resource_id, hex_token_id)

      %URI{scheme: _, path: "/ipfs/" <> resource_id} ->
        fetch_from_ipfs(resource_id, hex_token_id)

      %URI{scheme: _, path: "ipfs/" <> resource_id} ->
        fetch_from_ipfs(resource_id, hex_token_id)

      %URI{scheme: scheme} when not is_nil(scheme) ->
        fetch_metadata_inner(token_uri_string, ipfs_params, token_id, hex_token_id, from_base_uri?)

      %URI{path: path} ->
        case path do
          "Qm" <> <<_::binary-size(44)>> = resource_id ->
            fetch_from_ipfs(resource_id, hex_token_id)

          # todo: rewrite for strict CID v1 support
          "bafybe" <> _ = resource_id ->
            fetch_from_ipfs(resource_id, hex_token_id)

          _ ->
            json = ExplorerHelper.decode_json(token_uri_string, true)

            check_type(json, hex_token_id)
        end
    end
  rescue
    e ->
      Logger.warning(
        ["Unknown metadata format #{inspect(token_uri_string)}.", Exception.format(:error, e, __STACKTRACE__)],
        fetcher: :token_instances
      )

      {:error, "invalid token_uri_string"}
  end

  defp fetch_json_from_json_string(json, ipfs_params, token_id, hex_token_id, from_base_uri?, type) do
    decoded_json = URI.decode(json)

    fetch_json_from_uri({:ok, [decoded_json]}, ipfs_params, token_id, hex_token_id, from_base_uri?)
  rescue
    e ->
      Logger.warning(["Unknown metadata format #{inspect(json)}.", Exception.format(:error, e, __STACKTRACE__)],
        fetcher: :token_instances
      )

      {:error, "invalid #{type}"}
  end

  defp fetch_from_ipfs(ipfs_uid, hex_token_id) do
    ipfs_url = ipfs_link(ipfs_uid)
    public_ipfs_url = public_ipfs_link(ipfs_uid)

    ipfs_params = [ipfs?: true, public_ipfs_url: public_ipfs_url]

    fetch_metadata_inner(ipfs_url, ipfs_params, nil, hex_token_id)
  end

  defp fetch_from_arweave(uid, hex_token_id) do
    arweave_url = arweave_link(uid)

    ipfs_params = [ipfs?: false, arweave?: true]
    fetch_metadata_inner(arweave_url, ipfs_params, nil, hex_token_id)
  end

  defp fetch_metadata_inner(uri, ipfs_params, token_id, hex_token_id, from_base_uri? \\ false)

  defp fetch_metadata_inner(uri, ipfs_params, token_id, hex_token_id, from_base_uri?) do
    prepared_uri = substitute_token_id_to_token_uri(uri, token_id, hex_token_id, from_base_uri?)
    fetch_metadata_from_uri(prepared_uri, ipfs_params, hex_token_id)
  rescue
    e ->
      Logger.warning(
        ["Could not prepare token uri #{inspect(uri)}.", Exception.format(:error, e, __STACKTRACE__)],
        fetcher: :token_instances
      )

      {:error, "preparation error"}
  end

  @doc """
  Fetches metadata from a given URI.

  ## Parameters

    - `uri` (String): The URI from which to fetch metadata.
    - `ipfs_params` (keyword): Params for cases when metadata should be fetched from IPFS. Example: [ipfs?: true, public_ipfs_url: "https://ipfs.io/ipfs/{id}"]
    - `hex_token_id` (String, optional): A hexadecimal token ID, defaults to `nil`.

  ## Returns

    - `{:ok, metadata}` on success.
    - `{:error, reason}` on failure.

  ## Examples

      iex> fetch_metadata_from_uri("http://example.com/metadata", [ipfs?: false])
      {:ok, %{"name" => "Example Token", "description" => "An example token"}}

      iex> fetch_metadata_from_uri("http://localhost/metadata", [ipfs?: false])
      {:error, :blacklist}

  """
  @spec fetch_metadata_from_uri(String.t(), keyword(), String.t() | nil) :: {:ok, %{metadata: any}} | {:error, binary()}
  def fetch_metadata_from_uri(uri, ipfs_params, hex_token_id \\ nil) do
    case Application.get_env(:indexer, Indexer.Fetcher.TokenInstance.Helper)[:host_filtering_enabled?] &&
           !ipfs?(ipfs_params) && !arweave?(ipfs_params) && MetadataURIValidator.validate_uri(uri) do
      {:error, reason} ->
        if reason == :blacklist do
          Logger.warning(
            [
              "Request to token uri failed: #{inspect(uri)}.",
              "Host is blacklisted.",
              "To disable IPs blacklisting set INDEXER_TOKEN_INSTANCE_HOST_FILTERING_ENABLED=false"
            ],
            fetcher: :token_instances
          )
        end

        {:error, reason |> to_string() |> truncate_error()}

      _ ->
        fetch_metadata_from_uri_request(uri, hex_token_id, ipfs_params)
    end
  end

  defp fetch_metadata_from_uri_request(uri, hex_token_id, ipfs_params) do
    headers = if ipfs?(ipfs_params), do: ipfs_headers(), else: @default_headers

    case HttpClient.get(uri, headers,
           recv_timeout: 30_000,
           follow_redirect: true,
           pool: :token_instance_fetcher
         ) do
      {:ok, %{body: body, status_code: 200, headers: response_headers}} ->
        content_type = get_content_type_from_headers(response_headers)

        case check_content_type(content_type, uri, hex_token_id, body, ipfs_params) do
          {:ok, metadata} ->
            process_result(metadata, uri, ipfs_params)

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %{body: body, status_code: code}} ->
        Logger.debug(
          ["Request to token uri: #{inspect(uri)} failed with code #{code}. Body:", inspect(body)],
          fetcher: :token_instances
        )

        {:error_code, code}

      {:error, reason} ->
        Logger.warning(
          ["Request to token uri failed: #{inspect(uri)}.", inspect(reason)],
          fetcher: :token_instances
        )

        {:error, reason |> inspect() |> truncate_error()}
    end
  rescue
    e ->
      Logger.warning(
        ["Could not send request to token uri #{inspect(uri)}.", Exception.format(:error, e, __STACKTRACE__)],
        fetcher: :token_instances
      )

      {:error, "request error"}
  end

  defp process_result(metadata, uri, ipfs_params) do
    if arweave?(ipfs_params) || ipfs?(ipfs_params) do
      {:ok, metadata}
    else
      {:ok_store_uri, metadata, uri}
    end
  end

  defp ipfs?(ipfs_params) do
    Keyword.get(ipfs_params, :ipfs?)
  end

  defp arweave?(ipfs_params) do
    Keyword.get(ipfs_params, :arweave?)
  end

  defp check_content_type(content_type, uri, hex_token_id, body, ipfs_params) do
    image = image?(content_type)
    video = video?(content_type)
    public_ipfs_url = Keyword.get(ipfs_params, :public_ipfs_url)

    if content_type && (image || video) do
      json = if image, do: %{"image" => public_ipfs_url || uri}, else: %{"animation_url" => public_ipfs_url || uri}

      check_type(json, nil)
    else
      json = ExplorerHelper.decode_json(body, true)

      check_type(json, hex_token_id)
    end
  end

  defp get_content_type_from_headers(headers) do
    {_, content_type} =
      Enum.find(headers, fn {header_name, _header_value} ->
        String.downcase(header_name) == "content-type"
      end) || {nil, nil}

    content_type
  end

  defp image?(content_type) do
    content_type && String.starts_with?(content_type, "image/")
  end

  defp video?(content_type) do
    content_type && String.starts_with?(content_type, "video/")
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

  defp substitute_token_id_to_token_uri(base_uri, nil, _empty_token_id, true) do
    base_uri
  end

  defp substitute_token_id_to_token_uri(base_uri, token_id, _empty_token_id, true) do
    if String.ends_with?(base_uri, "/") do
      base_uri <> to_string(token_id)
    else
      base_uri <> "/" <> to_string(token_id)
    end
  end

  defp substitute_token_id_to_token_uri(token_uri, _token_id, empty_token_id, _from_base_uri?)
       when empty_token_id in [nil, ""],
       do: token_uri

  defp substitute_token_id_to_token_uri(token_uri, _token_id, hex_token_id, _from_base_uri?) do
    String.replace(token_uri, @erc1155_token_id_placeholder, hex_token_id)
  end

  @doc """
    Truncate error string to @max_error_length symbols
  """
  @spec truncate_error(binary()) :: binary()
  def truncate_error(error) do
    if String.length(error) > @max_error_length - 2 do
      String.slice(error, 0, @max_error_length - 3) <> "..."
    else
      error
    end
  end
end
