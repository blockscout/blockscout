defmodule Explorer.SmartContract.Reader do
  @moduledoc """
  Reads Smart Contract functions from the blockchain.

  For information on smart contract's Application Binary Interface (ABI), visit the
  [wiki](https://github.com/ethereum/wiki/wiki/Ethereum-Contract-ABI).
  """

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.{Block, Hash}
  alias EthereumJSONRPC.Encoder

  @typedoc """
  Map of functions to call with the values for the function to be called with.
  """
  @type functions :: %{String.t() => [term()]}

  @typedoc """
  Map of function call to function call results.
  """
  @type functions_results :: %{String.t() => {:ok, term()} | {:error, String.t()}}

  @typedoc """
  Options that can be forwarded when calling the Ethereum JSON RPC.

  ## Required

  * `:json_rpc_named_arguments` - the named arguments to `EthereumJSONRPC.json_rpc/2`.

  ## Optional

  * `:block_number` - the block in which to execute the function. Defaults to the `nil` to indicate
  the latest block as determined by the remote node, which may differ from the latest block number
  in `Explorer.Chain`.
  """
  @type contract_call_options :: [
          {:json_rpc_named_arguments, EthereumJSONRPC.json_rpc_named_arguments()},
          {:block_number, Block.block_number()}
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
  Runs contract functions on a given address for an unverified contract with an expected ABI.

  ## Options

  * `:json_rpc_named_arguments` - Options to forward for calling the Ethereum JSON RPC. See
    `t:EthereumJSONRPC.json_rpc_named_arguments.t/0` for full list of options.
  """
  @spec query_unverified_contract(Hash.Address.t(), [map()], functions(), contract_call_options()) ::
          functions_results()
  def query_unverified_contract(
        %Hash{byte_count: unquote(Hash.Address.byte_count())} = address,
        abi,
        functions,
        opts \\ []
      ) do
    contract_address = Hash.to_string(address)

    query_contract(contract_address, abi, functions, opts)
  end

  @spec query_contract(
          String.t(),
          term(),
          functions(),
          contract_call_options()
        ) :: functions_results()
  def query_contract(contract_address, abi, functions, opts \\ []) do
    json_rpc_named_arguments =
      Keyword.get(opts, :json_rpc_named_arguments) || Application.get_env(:explorer, :json_rpc_named_arguments)

    abi
    |> Encoder.encode_abi(functions)
    |> Enum.map(&setup_call_payload(&1, contract_address))
    |> EthereumJSONRPC.execute_contract_functions(json_rpc_named_arguments, opts)
    |> decode_results(abi, functions)
  rescue
    error ->
      format_error(functions, error.message)
  end

  defp decode_results({:ok, results}, abi, functions), do: Encoder.decode_abi_results(results, abi, functions)

  defp decode_results({:error, {:bad_gateway, request_url}}, _abi, functions) do
    Logger.error(fn ->
      [
        "BadGateway in #{request_url} while interacting with Contract functions: ",
        inspect(functions)
      ]
    end)

    format_error(functions, "Bad Gateway")
  end

  defp format_error(functions, message) do
    functions
    |> Enum.map(fn {function_name, _args} ->
      %{function_name => {:error, message}}
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
      {integer, remainder_of_binary} when remainder_of_binary == "" -> integer
      _ -> item
    end
  end

  def link_outputs_and_values(blockchain_values, outputs, function_name) do
    {_, value} = Map.get(blockchain_values, function_name, {:ok, [""]})

    for output <- outputs do
      new_value(output, List.wrap(value))
    end
  end

  defp new_value(%{"type" => "address"} = output, [value]) do
    Map.put_new(output, "value", bytes_to_string(value))
  end

  defp new_value(%{"type" => "bytes" <> _number} = output, [value]) do
    Map.put_new(output, "value", bytes_to_string(value))
  end

  defp new_value(output, [value]) do
    Map.put_new(output, "value", value)
  end

  @spec bytes_to_string(<<_::_*8>>) :: String.t()
  defp bytes_to_string(value) do
    Hash.to_string(%Hash{byte_count: byte_size(value), bytes: value})
  end
end
