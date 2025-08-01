defmodule Explorer.SmartContract.Helper do
  @moduledoc """
  SmartContract helper functions
  """

  alias Explorer.{Chain, Helper}
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.SmartContract.{Reader, Writer}
  alias Phoenix.HTML

  @api_true [api?: true]

  def queryable_method?(method) do
    method["constant"] || method["stateMutability"] == "view" || method["stateMutability"] == "pure"
  end

  def constructor?(function), do: function["type"] == "constructor"

  def event?(function), do: function["type"] == "event"

  def error?(function), do: function["type"] == "error"

  @doc """
    Checks whether the function which is not queryable can be considered as read
    function or not.
  """
  @spec read_with_wallet_method?(%{}) :: true | false
  def read_with_wallet_method?(function),
    do:
      !error?(function) && !event?(function) && !constructor?(function) &&
        !empty_outputs?(function) && !Writer.write_function?(function)

  def empty_outputs?(function), do: is_nil(function["outputs"]) || function["outputs"] == []

  def payable?(function), do: function["stateMutability"] == "payable" || function["payable"]

  def nonpayable?(function) do
    if function["type"] do
      function["stateMutability"] == "nonpayable" ||
        (!function["payable"] && !function["constant"] && !function["stateMutability"])
    else
      false
    end
  end

  def add_contract_code_md5(%{address_hash: address_hash_string} = attrs) when is_binary(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      attrs_extend_with_contract_code_md5(attrs, address)
    else
      _ -> attrs
    end
  end

  def add_contract_code_md5(%{address_hash: address_hash} = attrs) do
    case Chain.hash_to_address(address_hash) do
      {:ok, address} ->
        attrs_extend_with_contract_code_md5(attrs, address)

      _ ->
        attrs
    end
  end

  def add_contract_code_md5(attrs), do: attrs

  def contract_code_md5(bytes) do
    :md5
    |> :crypto.hash(bytes)
    |> Base.encode16(case: :lower)
  end

  defp attrs_extend_with_contract_code_md5(attrs, address) do
    if address.contract_code do
      contract_code_md5 = contract_code_md5(address.contract_code.bytes)

      attrs
      |> Map.put_new(:contract_code_md5, contract_code_md5)
    else
      attrs
    end
  end

  def sanitize_input(nil), do: nil

  def sanitize_input(input) do
    input
    |> HTML.html_escape()
    |> HTML.safe_to_string()
    |> String.trim()
  end

  def sol_file?(filename) do
    case List.last(String.split(String.downcase(filename), ".")) do
      "sol" ->
        true

      _ ->
        false
    end
  end

  def json_file?(filename) do
    case List.last(String.split(String.downcase(filename), ".")) do
      "json" ->
        true

      _ ->
        false
    end
  end

  @doc """
  Prepares the bytecode for a microservice by processing the given body, creation input, and deployed bytecode.

  ## Parameters

    - body: The body of the request or data to be processed.
    - creation_input: The input data used during the creation of the smart contract.
    - deployed_bytecode: The bytecode of the deployed smart contract.

  ## Returns

  The processed bytecode ready for the microservice.
  """
  @spec prepare_bytecode_for_microservice(map(), binary() | nil, binary() | nil) :: map()
  def prepare_bytecode_for_microservice(body, creation_input, deployed_bytecode)

  def prepare_bytecode_for_microservice(body, creation_input, deployed_bytecode) when is_nil(creation_input) do
    if Application.get_env(:explorer, :chain_type) == :zksync do
      body
      |> Map.put("code", deployed_bytecode)
    else
      body
      |> Map.put("bytecodeType", "DEPLOYED_BYTECODE")
      |> Map.put("bytecode", deployed_bytecode)
    end
  end

  def prepare_bytecode_for_microservice(body, creation_bytecode, _deployed_bytecode) do
    body
    |> Map.put("bytecodeType", "CREATION_INPUT")
    |> Map.put("bytecode", creation_bytecode)
  end

  def cast_libraries(map) do
    map |> Map.values() |> List.first() |> cast_libraries(map)
  end

  def cast_libraries(value, map) when is_map(value),
    do:
      map
      |> Map.values()
      |> Enum.reduce(%{}, fn map, acc -> Map.merge(acc, map) end)

  def cast_libraries(_value, map), do: map

  def contract_creation_input(address_hash) do
    case Chain.smart_contract_creation_transaction_bytecode(address_hash) do
      %{init: init, created_contract_code: _created_contract_code} ->
        init

      _ ->
        nil
    end
  end

  @doc """
    Returns a tuple: `{creation_bytecode, deployed_bytecode, metadata}` where `metadata` is a map:
      {
        "blockNumber": "string",
        "chainId": "string",
        "contractAddress": "string",
        "creationCode": "string",
        "deployer": "string",
        "runtimeCode": "string",
        "transactionHash": "string",
        "transactionIndex": "string"
      }

    Metadata will be sent to a verifier microservice
  """
  @spec fetch_data_for_verification(binary() | Hash.t()) :: {binary() | nil, binary(), map()}
  def fetch_data_for_verification(address_hash) do
    deployed_bytecode = Chain.smart_contract_bytecode(address_hash)

    metadata = %{
      "contractAddress" => to_string(address_hash),
      "runtimeCode" => to_string(deployed_bytecode),
      "chainId" => Application.get_env(:block_scout_web, :chain_id)
    }

    if Application.get_env(:explorer, :chain_type) == :zksync do
      {nil, deployed_bytecode, metadata}
    else
      case SmartContract.creation_transaction_with_bytecode(address_hash) do
        %{init: init, transaction: transaction} ->
          {init, deployed_bytecode, transaction |> transaction_to_metadata(init) |> Map.merge(metadata)}

        %{init: init, internal_transaction: internal_transaction} ->
          {init, deployed_bytecode,
           internal_transaction |> internal_transaction_to_metadata(init) |> Map.merge(metadata)}

        _ ->
          {nil, deployed_bytecode, metadata}
      end
    end
  end

  defp transaction_to_metadata(transaction, init) do
    %{
      "blockNumber" => to_string(transaction.block_number),
      "transactionHash" => to_string(transaction.hash),
      "transactionIndex" => to_string(transaction.index),
      "deployer" => to_string(transaction.from_address_hash),
      "creationCode" => to_string(init)
    }
  end

  defp internal_transaction_to_metadata(internal_transaction, init) do
    %{
      "blockNumber" => to_string(internal_transaction.block_number),
      "transactionHash" => to_string(internal_transaction.transaction_hash),
      "transactionIndex" => to_string(internal_transaction.transaction_index),
      "deployer" => to_string(internal_transaction.from_address_hash),
      "creationCode" => to_string(init)
    }
  end

  @doc """
    Prepare license type for verification.
  """
  @spec prepare_license_type(any()) :: atom() | integer() | binary() | nil
  def prepare_license_type(atom_or_integer) when is_atom(atom_or_integer) or is_integer(atom_or_integer),
    do: atom_or_integer

  def prepare_license_type(binary) when is_binary(binary), do: Helper.parse_integer(binary) || binary
  def prepare_license_type(_), do: nil

  @doc """
  Pre-fetches implementation for unverified smart-contract or verified proxy smart-contract
  """
  @spec pre_fetch_implementations(Address.t()) :: Implementation.t() | nil
  def pre_fetch_implementations(address) do
    implementation =
      with {:verified_smart_contract, %SmartContract{}} <- {:verified_smart_contract, address.smart_contract},
           {:proxy?, true} <- {:proxy?, address_is_proxy?(address, @api_true)},
           # we should fetch implementations only for original smart-contract and exclude fetching implementations of bytecode twin
           {:bytecode_twin?, false} <- {:bytecode_twin?, address.hash != address.smart_contract.address_hash} do
        Implementation.get_implementation(address.smart_contract, @api_true)
      else
        {:bytecode_twin?, true} ->
          nil

        {:verified_smart_contract, _} ->
          if Address.smart_contract?(address) do
            smart_contract = %SmartContract{
              address_hash: address.hash
            }

            Implementation.get_implementation(smart_contract, @api_true)
          end

        {:proxy?, false} ->
          nil
      end

    implementation
    |> Chain.select_repo(@api_true).preload(Implementation.proxy_implementations_addresses_association())
  end

  @doc """
  Checks if given address is proxy smart contract
  """
  @spec address_is_proxy?(Address.t(), list()) :: boolean()
  def address_is_proxy?(address, options \\ [])

  def address_is_proxy?(%Address{smart_contract: %SmartContract{} = smart_contract}, options) do
    Proxy.proxy_contract?(smart_contract, options)
  end

  def address_is_proxy?(%Address{smart_contract: _}, _), do: false

  @doc """
  Gets binary hash string from contract's getter.
  """
  @spec get_binary_string_from_contract_getter(binary(), binary(), SmartContract.abi(), list()) ::
          binary() | [binary()] | nil | :error
  def get_binary_string_from_contract_getter(signature, address_hash_string, abi, params \\ []) do
    binary_hash =
      case Reader.query_contract(
             address_hash_string,
             abi,
             %{
               "#{signature}" => params
             },
             false
           ) do
        %{^signature => {:ok, [result]}} ->
          result

        %{^signature => {:error, _error}} ->
          :error

        _ ->
          nil
      end

    # todo: Dangerous, fix with https://github.com/blockscout/blockscout/issues/12544
    ExplorerHelper.add_0x_prefix(binary_hash)
  end
end
