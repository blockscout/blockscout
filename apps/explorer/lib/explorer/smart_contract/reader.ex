defmodule Explorer.SmartContract.Reader do
  @moduledoc """
  Reads Smart Contract functions from the blockchain.

  For information on smart contract's Application Binary Interface (ABI), visit the
  [wiki](https://github.com/ethereum/wiki/wiki/Ethereum-Contract-ABI).
  """

  alias Explorer.Chain
  alias EthereumJSONRPC.Encoder
  alias Explorer.Chain.Hash

  @doc """
  Queries the contract functions on the blockchain and returns the call results.

  ## Examples

  Note that for this example to work the database must be up to date with the
  information available in the blockchain.

  ```
  $ Explorer.SmartContract.Reader.query_contract(
    %Explorer.Chain.Hash{
      byte_count: 20,
      bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    },
    %{"sum" => [20, 22]}
  )
  # => %{"sum" => [42]}

  $ Explorer.SmartContract.Reader.query_contract(
    %Explorer.Chain.Hash{
      byte_count: 20,
      bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    },
    %{"sum" => [1, "abc"]}
  )
  # => %{"sum" => ["Data overflow encoding int, data `abc` cannot fit in 256 bits"]}
  ```
  """
  @spec query_contract(%Explorer.Chain.Hash{}, %{String.t() => [term()]}) :: map()
  def query_contract(address_hash, functions) do
    contract_address = Hash.to_string(address_hash)

    abi =
      address_hash
      |> Chain.address_hash_to_smart_contract()
      |> Map.get(:abi)

    try do
      blockchain_result =
        abi
        |> Encoder.encode_abi(functions)
        |> Enum.map(&setup_call_payload(&1, contract_address))
        |> EthereumJSONRPC.execute_contract_functions()

      Encoder.decode_abi_results(blockchain_result, abi, functions)
    rescue
      error ->
        format_error(functions, error.message)
    end
  end

  defp format_error(functions, message) do
    functions
    |> Enum.map(fn {function_name, _args} ->
      %{function_name => [message]}
    end)
    |> List.first()
  end

  @doc """
  Given the encoded data that references a function and its arguments in the blockchain, as well as the contract address, returns what EthereumJSONRPC.execute_contract_functions expects.
  """
  @spec setup_call_payload({%ABI.FunctionSelector{}, [term()]}, String.t()) :: map()
  def setup_call_payload({function_name, data}, contract_address) do
    %{
      contract_address: contract_address,
      data: data,
      id: function_name
    }
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
          "outputs" => [%{"name" => "", "type" => "uint256", "value" => 0}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        },
        %{
          "constant" => true,
          "inputs" => [%{"name" => "x", "type" => "uint256"}],
          "name" => "with_arguments",
          "outputs" => [%{"name" => "", "type" => "bool", "value" => ""}],
          "payable" => false,
          "stateMutability" => "view",
          "type" => "function"
        }
      ]
  """
  @spec read_only_functions(%Explorer.Chain.Hash{}) :: [%{}]
  def read_only_functions(contract_address_hash) do
    contract_address_hash
    |> Chain.address_hash_to_smart_contract()
    |> Map.get(:abi, [])
    |> Enum.filter(& &1["constant"])
    |> fetch_current_value_from_blockchain(contract_address_hash, [])
    |> Enum.reverse()
  end

  def fetch_current_value_from_blockchain([%{"inputs" => []} = function | tail], contract_address_hash, acc) do
    values =
      fetch_from_blockchain(contract_address_hash, %{
        name: function["name"],
        args: function["inputs"],
        outputs: function["outputs"]
      })

    formatted = Map.replace!(function, "outputs", values)

    fetch_current_value_from_blockchain(tail, contract_address_hash, [formatted | acc])
  end

  def fetch_current_value_from_blockchain([function | tail], contract_address_hash, acc) do
    values = link_outputs_and_values(%{}, Map.get(function, "outputs", []), function["name"])

    formatted = Map.replace!(function, "outputs", values)

    fetch_current_value_from_blockchain(tail, contract_address_hash, [formatted | acc])
  end

  def fetch_current_value_from_blockchain([], _contract_address_hash, acc), do: acc

  @doc """
  Fetches the blockchain value of a function that requires arguments.
  """
  @spec query_function(String.t(), %{name: String.t(), args: nil}) :: [%{}]
  def query_function(contract_address_hash, %{name: name, args: nil}) do
    query_function(contract_address_hash, %{name: name, args: []})
  end

  @spec query_function(%Explorer.Chain.Hash{}, %{name: String.t(), args: [term()]}) :: [%{}]
  def query_function(contract_address_hash, %{name: name, args: args}) do
    function =
      contract_address_hash
      |> Chain.address_hash_to_smart_contract()
      |> Map.get(:abi, [])
      |> Enum.filter(fn function -> function["name"] == name end)
      |> List.first()

    fetch_from_blockchain(contract_address_hash, %{name: name, args: args, outputs: function["outputs"]})
  end

  defp fetch_from_blockchain(contract_address_hash, %{name: name, args: args, outputs: outputs}) do
    contract_address_hash
    |> query_contract(%{name => normalize_args(args)})
    |> link_outputs_and_values(outputs, name)
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
      {integer, remainder_of_binary} when remainder_of_binary == "" -> integer
      _ -> item
    end
  end

  def link_outputs_and_values(blockchain_values, outputs, function_name) do
    values = Map.get(blockchain_values, function_name, [""])

    for output <- outputs, value <- values do
      new_value(output, value)
    end
  end

  defp new_value(%{"type" => "address"} = output, value) do
    Map.put_new(output, "value", bytes_to_string(value))
  end

  defp new_value(%{"type" => "bytes" <> _number} = output, value) do
    Map.put_new(output, "value", bytes_to_string(value))
  end

  defp new_value(output, value) do
    Map.put_new(output, "value", value)
  end

  @spec bytes_to_string(<<_::_*8>>) :: String.t()
  defp bytes_to_string(value) do
    Hash.to_string(%Hash{byte_count: byte_size(value), bytes: value})
  end
end
