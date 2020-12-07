defmodule Explorer.SmartContract.Reader do
  @moduledoc """
  Reads Smart Contract functions from the blockchain.

  For information on smart contract's Application Binary Interface (ABI), visit the
  [wiki](https://github.com/ethereum/wiki/wiki/Ethereum-Contract-ABI).
  """

  alias EthereumJSONRPC.Contract
  alias Explorer.Chain
  alias Explorer.Chain.{Hash, SmartContract}

  @typedoc """
  Map of functions to call with the values for the function to be called with.
  """
  @type functions :: %{String.t() => [term()]}

  @typedoc """
  Map of function call to function call results.
  """
  @type functions_results :: %{String.t() => Contract.call_result()}

  @typedoc """
  Options that can be forwarded when calling the Ethereum JSON RPC.

  ## Optional

  * `:json_rpc_named_arguments` - the named arguments to `EthereumJSONRPC.json_rpc/2`.
  """
  @type contract_call_options :: [
          {:json_rpc_named_arguments, EthereumJSONRPC.json_rpc_named_arguments()}
        ]

  @doc """
  Queries the contract functions on the blockchain and returns the call results.

  Optionally accepts the abi if it has already been fetched.

  ## Examples

  Note that for this example to work the database must be up to date with the
  information available in the blockchain.

      $ Explorer.SmartContract.Reader.query_verified_contract(
        %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
        },
        %{"sum" => [20, 22]}
      )
      # => %{"sum" => {:ok, [42]}}

      $ Explorer.SmartContract.Reader.query_verified_contract(
        %Explorer.Chain.Hash{
          byte_count: 20,
          bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
        },
        %{"sum" => [1, "abc"]}
      )
      # => %{"sum" => {:error, "Data overflow encoding int, data `abc` cannot fit in 256 bits"}}
  """
  @spec query_verified_contract(Hash.Address.t(), functions(), SmartContract.abi() | nil) :: functions_results()
  def query_verified_contract(address_hash, functions, mabi \\ nil) do
    contract_address = Hash.to_string(address_hash)

    abi =
      case mabi do
        nil ->
          address_hash
          |> Chain.address_hash_to_smart_contract()
          |> Map.get(:abi)

        _ ->
          mabi
      end

    query_contract(contract_address, abi, functions)
  end

  @doc """
  Runs contract functions on a given address for smart contract with an expected ABI and functions.

  This function can be used to read data from smart contracts that are not verified (like token contracts)
  since it receives the ABI as an argument.

  ## Options

  * `:json_rpc_named_arguments` - Options to forward for calling the Ethereum JSON RPC. See
    `t:EthereumJSONRPC.json_rpc_named_arguments.t/0` for full list of options.
  """
  @spec query_contract(
          String.t(),
          term(),
          functions()
        ) :: functions_results()
  def query_contract(contract_address, abi, functions) do
    query_contract_inner(contract_address, abi, functions, nil, nil)
  end

  @spec query_contract(
          String.t(),
          String.t(),
          term(),
          functions()
        ) :: functions_results()
  def query_contract(contract_address, from, abi, functions) do
    query_contract_inner(contract_address, abi, functions, nil, from)
  end

  @spec query_contract_by_block_number(
          String.t(),
          term(),
          functions(),
          non_neg_integer()
        ) :: functions_results()
  def query_contract_by_block_number(contract_address, abi, functions, block_number) do
    query_contract_inner(contract_address, abi, functions, block_number, nil)
  end

  defp query_contract_inner(contract_address, abi, functions, block_number, from) do
    requests =
      functions
      |> Enum.map(fn {method_id, args} ->
        %{
          contract_address: contract_address,
          from: from,
          method_id: method_id,
          args: args,
          block_number: block_number
        }
      end)

    requests
    |> query_contracts(abi)
    |> Enum.zip(requests)
    |> Enum.into(%{}, fn {response, request} ->
      {request.method_id, response}
    end)
  end

  @doc """
  Runs batch of contract functions on given addresses for smart contract with an expected ABI and functions.

  This function can be used to read data from smart contracts that are not verified (like token contracts)
  since it receives the ABI as an argument.

  ## Options

  * `:json_rpc_named_arguments` - Options to forward for calling the Ethereum JSON RPC. See
    `t:EthereumJSONRPC.json_rpc_named_arguments.t/0` for full list of options.
  """
  @spec query_contracts([Contract.call()], term(), contract_call_options()) :: [Contract.call_result()]
  def query_contracts(requests, abi, opts \\ []) do
    json_rpc_named_arguments =
      Keyword.get(opts, :json_rpc_named_arguments) || Application.get_env(:explorer, :json_rpc_named_arguments)

    EthereumJSONRPC.execute_contract_functions(requests, abi, json_rpc_named_arguments)
  end

  @doc """
  List all the smart contract functions with its current value from the
  blockchain, following the ABI order.

  Functions that require arguments can be queryable but won't list the current
  value at this moment.

  ## Examples

    $ Explorer.SmartContract.Reader.read_only_functions("0x798465571ae21a184a272f044f991ad1d5f87a3f")
    => [
        %{
          "constant" => true,
          "inputs" => [],
          "name" => "get",
          "outputs" => [%{"name" => "", "type" => "uint256", "value" => [0]}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [%{"name" => "x", "type" => "uint256"}],
          "name" => "with_arguments",
          "outputs" => [%{"name" => "", "type" => "bool", "value" => [""]}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        }
      ]
  """
  @spec read_only_functions(Hash.t()) :: [%{}]
  def read_only_functions(contract_address_hash) do
    abi =
      contract_address_hash
      |> Chain.address_hash_to_smart_contract()
      |> Map.get(:abi)

    case abi do
      nil ->
        []

      _ ->
        abi_with_method_id = get_abi_with_method_id(abi)

        abi_with_method_id
        |> Enum.filter(&(&1["constant"] || &1["stateMutability"] == "view"))
        |> Enum.map(&fetch_current_value_from_blockchain(&1, abi_with_method_id, contract_address_hash))
    end
  end

  def read_only_functions_proxy(contract_address_hash, implementation_address_hash_string) do
    implementation_abi = Chain.get_implementation_abi(implementation_address_hash_string)

    case implementation_abi do
      nil ->
        []

      _ ->
        implementation_abi_with_method_id = get_abi_with_method_id(implementation_abi)

        implementation_abi_with_method_id
        |> Enum.filter(&(&1["constant"] || &1["stateMutability"] == "view"))
        |> Enum.map(&fetch_current_value_from_blockchain(&1, implementation_abi_with_method_id, contract_address_hash))
    end
  end

  defp get_abi_with_method_id(abi) do
    parsed_abi =
      abi
      |> ABI.parse_specification()

    abi_with_method_id =
      abi
      |> Enum.map(fn target_method ->
        methods =
          parsed_abi
          |> Enum.filter(fn method ->
            Atom.to_string(method.type) == Map.get(target_method, "type") &&
              method.function == Map.get(target_method, "name") &&
              Enum.count(method.input_names) == Enum.count(Map.get(target_method, "inputs")) &&
              input_types_matched?(method.types, target_method)
          end)

        if Enum.count(methods) > 0 do
          method = Enum.at(methods, 0)
          method_id = Map.get(method, :method_id)
          method_with_id = Map.put(target_method, "method_id", Base.encode16(method_id, case: :lower))
          method_with_id
        else
          target_method
        end
      end)

    abi_with_method_id
  end

  defp input_types_matched?(types, target_method) do
    types
    |> Enum.with_index()
    |> Enum.all?(fn {target_type, index} ->
      type_to_compare = Map.get(Enum.at(Map.get(target_method, "inputs"), index), "type")
      target_type_formatted = format_type(target_type)
      target_type_formatted == type_to_compare
    end)
  end

  defp format_type(input_type) do
    case input_type do
      {:array, type, array_size} ->
        format_type(type) <> "[" <> Integer.to_string(array_size) <> "]"

      {:array, type} ->
        format_type(type) <> "[]"

      {:tuple, tuple} ->
        format_tuple_type(tuple)

      {type, size} ->
        Atom.to_string(type) <> Integer.to_string(size)

      type ->
        Atom.to_string(type)
    end
  end

  defp format_tuple_type(tuple) do
    tuple_types =
      tuple
      |> Enum.reduce(nil, fn tuple_item, acc ->
        if acc do
          acc <> "," <> format_type(tuple_item)
        else
          format_type(tuple_item)
        end
      end)

    "tuple[#{tuple_types}]"
  end

  def fetch_current_value_from_blockchain(function, abi, contract_address_hash) do
    values =
      case function do
        %{"inputs" => []} ->
          method_id = function["method_id"]
          args = function["inputs"]
          outputs = function["outputs"]

          contract_address_hash
          |> query_verified_contract(%{method_id => normalize_args(args)}, abi)
          |> link_outputs_and_values(outputs, method_id)

        _ ->
          link_outputs_and_values(%{}, Map.get(function, "outputs", []), function["method_id"])
      end

    Map.replace!(function, "outputs", values)
  end

  @doc """
  Fetches the blockchain value of a function that requires arguments.
  """
  @spec query_function(String.t(), %{method_id: String.t(), args: nil}, atom()) :: [%{}]
  def query_function(contract_address_hash, %{method_id: method_id, args: nil}, type) do
    query_function(contract_address_hash, %{method_id: method_id, args: []}, type)
  end

  @spec query_function(Hash.t(), %{method_id: String.t(), args: [term()]}, atom()) :: [%{}]
  def query_function(contract_address_hash, %{method_id: method_id, args: args}, type) do
    abi =
      contract_address_hash
      |> Chain.address_hash_to_smart_contract()
      |> Map.get(:abi)

    final_abi =
      if type == :proxy do
        Chain.get_implementation_abi_from_proxy(contract_address_hash, abi)
      else
        abi
      end

    parsed_final_abi =
      final_abi
      |> ABI.parse_specification()

    %{outputs: outputs, method_id: method_id} =
      case parsed_final_abi do
        nil ->
          nil

        _ ->
          function_object = find_function_by_method(parsed_final_abi, method_id)

          %ABI.FunctionSelector{returns: returns, method_id: method_id} = function_object

          outputs = extract_outputs(returns)

          %{outputs: outputs, method_id: method_id}
      end

    contract_address_hash
    |> query_verified_contract(%{method_id => normalize_args(args)}, final_abi)
    |> link_outputs_and_values(outputs, method_id)
  end

  defp find_function_by_method(parsed_abi, method_id) do
    parsed_abi
    |> Enum.filter(fn %ABI.FunctionSelector{method_id: find_method_id} ->
      if find_method_id do
        Base.encode16(find_method_id, case: :lower) == method_id || find_method_id == method_id
      else
        find_method_id == method_id
      end
    end)
    |> List.first()
  end

  defp extract_outputs(returns) do
    returns
    |> Enum.map(fn output ->
      case output do
        {:array, type, array_size} ->
          %{"type" => format_type(type) <> "[" <> Integer.to_string(array_size) <> "]"}

        {:array, type} ->
          %{"type" => format_type(type) <> "[]"}

        {:tuple, tuple} ->
          %{"type" => format_tuple_type(tuple)}

        {type, size} ->
          full_type = Atom.to_string(type) <> Integer.to_string(size)
          %{"type" => full_type}

        type ->
          %{"type" => type}
      end
    end)
  end

  @doc """
  The type of the arguments passed to the blockchain interferes in the output,
  but we always get strings from the front, so it is necessary to normalize it.
  """
  def normalize_args(args) do
    Enum.map(args, &parse_item/1)
  end

  defp parse_item("true"), do: true
  defp parse_item("false"), do: false

  defp parse_item(item) do
    response = Integer.parse(item)

    case response do
      {integer, ""} ->
        hex_encoding =
          integer
          |> :binary.encode_unsigned()
          |> Base.encode16(case: :lower)

        "0x" <> hex_encoding

      _ ->
        item
    end
  end

  def link_outputs_and_values(blockchain_values, outputs, method_id) do
    default_value = Enum.map(outputs, fn _ -> "" end)
    {_, value} = Map.get(blockchain_values, method_id, {:ok, default_value})

    for {output, index} <- Enum.with_index(outputs) do
      new_value(output, List.wrap(value), index)
    end
  end

  defp new_value(%{"type" => "address"} = output, [value], _index) do
    Map.put_new(output, "value", value)
  end

  defp new_value(%{"type" => :address} = output, [value], _index) do
    Map.put_new(output, "value", value)
  end

  defp new_value(%{"type" => "address"} = output, values, index) do
    Map.put_new(output, "value", Enum.at(values, index))
  end

  defp new_value(%{"type" => :address} = output, values, index) do
    Map.put_new(output, "value", Enum.at(values, index))
  end

  defp new_value(%{"type" => "bytes" <> number_rest} = output, values, index) do
    if String.contains?(number_rest, "[]") do
      values_array = Enum.at(values, index)

      values_array_formatted =
        Enum.map(values_array, fn value ->
          bytes_to_string(value)
        end)

      Map.put_new(output, "value", values_array_formatted)
    else
      Map.put_new(output, "value", bytes_to_string(Enum.at(values, index)))
    end
  end

  defp new_value(%{"type" => "bytes"} = output, values, index) do
    Map.put_new(output, "value", bytes_to_string(Enum.at(values, index)))
  end

  defp new_value(%{"type" => :bytes} = output, values, index) do
    Map.put_new(output, "value", bytes_to_string(Enum.at(values, index)))
  end

  defp new_value(output, [value], _index) do
    Map.put_new(output, "value", value)
  end

  defp new_value(output, values, index) do
    Map.put_new(output, "value", Enum.at(values, index))
  end

  @spec bytes_to_string(<<_::_*8>>) :: String.t()
  defp bytes_to_string(value) do
    if value do
      Hash.to_string(%Hash{byte_count: byte_size(value), bytes: value})
    else
      "0x"
    end
  end
end
