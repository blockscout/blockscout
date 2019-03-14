defmodule Explorer.SmartContract.Reader do
  @moduledoc """
  Reads Smart Contract functions from the blockchain.

  For information on smart contract's Application Binary Interface (ABI), visit the
  [wiki](https://github.com/ethereum/wiki/wiki/Ethereum-Contract-ABI).
  """

  alias EthereumJSONRPC.Contract
  alias Explorer.Chain
  alias Explorer.Chain.Hash

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
  @spec query_verified_contract(Hash.Address.t(), functions()) :: functions_results()
  def query_verified_contract(address_hash, functions) do
    contract_address = Hash.to_string(address_hash)

    abi =
      address_hash
      |> Chain.address_hash_to_smart_contract()
      |> Map.get(:abi)

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
    requests =
      functions
      |> Enum.map(fn {function_name, args} ->
        %{
          contract_address: contract_address,
          function_name: function_name,
          args: args
        }
      end)

    requests
    |> query_contracts(abi)
    |> Enum.zip(requests)
    |> Enum.into(%{}, fn {response, request} ->
      {request.function_name, response}
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
    contract_address_hash
    |> Chain.address_hash_to_smart_contract()
    |> Map.get(:abi, [])
    |> Enum.filter(& &1["constant"])
    |> fetch_current_value_from_blockchain(contract_address_hash, [])
    |> Enum.reverse()
  end

  def fetch_current_value_from_blockchain(
        [%{"inputs" => []} = function | tail],
        contract_address_hash,
        acc
      ) do
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

  @spec query_function(Hash.t(), %{name: String.t(), args: [term()]}) :: [%{}]
  def query_function(contract_address_hash, %{name: name, args: args}) do
    function =
      contract_address_hash
      |> Chain.address_hash_to_smart_contract()
      |> Map.get(:abi, [])
      |> Enum.filter(fn function -> function["name"] == name end)
      |> List.first()

    fetch_from_blockchain(contract_address_hash, %{
      name: name,
      args: args,
      outputs: function["outputs"]
    })
  end

  defp fetch_from_blockchain(contract_address_hash, %{name: name, args: args, outputs: outputs}) do
    contract_address_hash
    |> query_verified_contract(%{name => normalize_args(args)})
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

  def link_outputs_and_values(blockchain_values, outputs, function_name) do
    {_, value} = Map.get(blockchain_values, function_name, {:ok, [""]})

    for {output, index} <- Enum.with_index(outputs) do
      new_value(output, List.wrap(value), index)
    end
  end

  defp new_value(%{"type" => "address"} = output, [value], _index) do
    Map.put_new(output, "value", bytes_to_string(value))
  end

  defp new_value(%{"type" => "bytes" <> _number} = output, [value], _index) do
    Map.put_new(output, "value", bytes_to_string(value))
  end

  defp new_value(output, [value], _index) do
    Map.put_new(output, "value", value)
  end

  defp new_value(output, values, index) do
    Map.put_new(output, "value", Enum.at(values, index))
  end

  @spec bytes_to_string(<<_::_*8>>) :: String.t()
  defp bytes_to_string(value) do
    Hash.to_string(%Hash{byte_count: byte_size(value), bytes: value})
  end
end
