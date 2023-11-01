defmodule Explorer.SmartContract.Helper do
  @moduledoc """
  SmartContract helper functions
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Hash, SmartContract}
  alias Phoenix.HTML

  def queriable_method?(method) do
    method["constant"] || method["stateMutability"] == "view" || method["stateMutability"] == "pure"
  end

  def constructor?(function), do: function["type"] == "constructor"

  def event?(function), do: function["type"] == "event"

  def error?(function), do: function["type"] == "error"

  @doc """
    Checks whether the function which is not queriable can be consider as read function or not.
  """
  @spec read_with_wallet_method?(%{}) :: true | false
  def read_with_wallet_method?(function),
    do:
      !error?(function) && !event?(function) && !constructor?(function) && nonpayable?(function) &&
        !empty_outputs?(function)

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
      contract_code_md5 = contract_code_md5(address.contract_code.bytes)

      attrs
      |> Map.put_new(:contract_code_md5, contract_code_md5)
    else
      _ -> attrs
    end
  end

  def add_contract_code_md5(%{address_hash: address_hash} = attrs) do
    case Chain.hash_to_address(address_hash) do
      {:ok, address} ->
        contract_code_md5 = contract_code_md5(address.contract_code.bytes)

        attrs
        |> Map.put_new(:contract_code_md5, contract_code_md5)

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

  def prepare_bytecode_for_microservice(body, creation_input, deployed_bytecode)

  def prepare_bytecode_for_microservice(body, empty, deployed_bytecode) when is_nil(empty) do
    body
    |> Map.put("bytecodeType", "DEPLOYED_BYTECODE")
    |> Map.put("bytecode", deployed_bytecode)
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
    case Chain.smart_contract_creation_tx_bytecode(address_hash) do
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

    case SmartContract.creation_tx_with_bytecode(address_hash) do
      %{init: init, tx: tx} ->
        {init, deployed_bytecode, tx |> tx_to_metadata(init) |> Map.merge(metadata)}

      %{init: init, internal_tx: internal_tx} ->
        {init, deployed_bytecode, internal_tx |> internal_tx_to_metadata(init) |> Map.merge(metadata)}

      _ ->
        {nil, deployed_bytecode, metadata}
    end
  end

  defp tx_to_metadata(tx, init) do
    %{
      "blockNumber" => to_string(tx.block_number),
      "transactionHash" => to_string(tx.hash),
      "transactionIndex" => to_string(tx.index),
      "deployer" => to_string(tx.from_address_hash),
      "creationCode" => to_string(init)
    }
  end

  defp internal_tx_to_metadata(internal_tx, init) do
    %{
      "blockNumber" => to_string(internal_tx.block_number),
      "transactionHash" => to_string(internal_tx.transaction_hash),
      "transactionIndex" => to_string(internal_tx.transaction_index),
      "deployer" => to_string(internal_tx.from_address_hash),
      "creationCode" => to_string(init)
    }
  end
end
