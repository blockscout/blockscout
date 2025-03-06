defmodule Explorer.SmartContract.Reader do
  @moduledoc """
  Reads Smart Contract functions from the blockchain.

  For information on smart contract's Application Binary Interface (ABI), visit the
  [wiki](https://docs.soliditylang.org/en/develop/abi-spec.html).
  """

  alias EthereumJSONRPC.{Contract, Encoder}
  alias Explorer.Chain.{Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.SmartContract.Helper

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

  @typep api? :: {:api?, true | false}

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
  @spec query_verified_contract(
          Hash.Address.t(),
          functions(),
          String.t() | nil,
          true | false,
          SmartContract.abi(),
          Keyword.t()
        ) ::
          functions_results()
  def query_verified_contract(address_hash, functions, from, leave_error_as_map, mabi, options \\ []) do
    query_verified_contract_inner(address_hash, functions, mabi, from, leave_error_as_map, options)
  end

  @spec query_verified_contract(Hash.Address.t(), functions(), true | false, SmartContract.abi() | nil) ::
          functions_results()
  def query_verified_contract(address_hash, functions, leave_error_as_map, mabi \\ nil) do
    query_verified_contract_inner(address_hash, functions, mabi, nil, leave_error_as_map)
  end

  @spec query_verified_contract_inner(
          Hash.Address.t(),
          functions(),
          SmartContract.abi() | nil,
          String.t() | nil,
          true | false,
          Keyword.t()
        ) ::
          functions_results()
  defp query_verified_contract_inner(address_hash, functions, mabi, from, leave_error_as_map, options \\ []) do
    contract_address = Hash.to_string(address_hash)

    abi = prepare_abi(mabi, address_hash)

    query_contract(contract_address, from, abi, functions, leave_error_as_map, options)
  end

  defp prepare_abi(nil, address_hash) do
    {smart_contract, _} =
      address_hash
      |> SmartContract.address_hash_to_smart_contract_with_bytecode_twin()

    smart_contract
    |> Map.get(:abi)
  end

  defp prepare_abi(mabi, _address_hash), do: mabi

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
          String.t() | nil,
          term(),
          functions(),
          true | false,
          Keyword.t()
        ) :: functions_results()
  def query_contract(contract_address, from \\ nil, abi, functions, leave_error_as_map, options \\ []) do
    query_contract_inner(contract_address, abi, functions, nil, from, leave_error_as_map, options)
  end

  @spec query_contract_by_block_number(
          String.t(),
          term(),
          functions(),
          non_neg_integer()
        ) :: functions_results()
  def query_contract_by_block_number(contract_address, abi, functions, block_number, leave_error_as_map \\ false) do
    query_contract_inner(contract_address, abi, functions, block_number, nil, leave_error_as_map)
  end

  defp query_contract_inner(contract_address, abi, functions, block_number, from, leave_error_as_map, options \\ []) do
    requests =
      functions
      |> Enum.map(fn {method_id, args} ->
        %{
          contract_address: contract_address,
          method_id: method_id,
          args: args,
          block_number: block_number
        }
        |> (&if(!is_nil(from) && from != "", do: Map.put(&1, :from, from), else: &1)).()
      end)

    requests
    |> query_contracts(abi, [], leave_error_as_map, options)
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

  @spec query_contracts([Contract.call()], term(), contract_call_options(), true | false, Keyword.t()) :: [
          Contract.call_result()
        ]
  def query_contracts(requests, abi, [], leave_error_as_map, options \\ []) do
    json_rpc_named_arguments =
      :explorer
      |> Application.get_env(:json_rpc_named_arguments)
      |> Keyword.merge(options)

    EthereumJSONRPC.execute_contract_functions(requests, abi, json_rpc_named_arguments, leave_error_as_map)
  end

  @doc """
  List all the smart contract functions with its current value from the
  blockchain, following the ABI order.

  Functions that require arguments can be queryable but won't list the current
  value at this moment.

  ## Examples

    $ Explorer.SmartContract.Reader.read_only_functions(%SmartContract{...})
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
  @spec read_only_functions(SmartContract.t(), Hash.t(), String.t() | nil, Keyword.t()) :: [%{}]
  def read_only_functions(smart_contract, contract_address_hash, from, options \\ [])

  def read_only_functions(%SmartContract{abi: abi}, contract_address_hash, from, options) do
    case abi do
      nil ->
        []

      _ ->
        read_only_functions_from_abi_with_sender(abi, contract_address_hash, from, options)
    end
  end

  def read_only_functions(nil, _, _, _), do: []

  def read_only_functions_proxy(contract_address_hash, implementation_address_hash_string, from, options \\ []) do
    implementation_abi = SmartContract.get_abi(implementation_address_hash_string, options)

    case implementation_abi do
      nil ->
        []

      _ ->
        read_only_functions_from_abi_with_sender(implementation_abi, contract_address_hash, from, options)
    end
  end

  @doc """
    Returns abi for not queryable functions of proxy's implementation which can be considered as read-only
  """
  @spec read_functions_required_wallet_proxy(String.t()) :: [%{}]
  def read_functions_required_wallet_proxy(implementation_address_hash_string) do
    implementation_abi = SmartContract.get_abi(implementation_address_hash_string)

    case implementation_abi do
      nil ->
        []

      _ ->
        read_functions_required_wallet_from_abi(implementation_abi)
    end
  end

  @doc """
    Returns abi for not queryable functions of the smart contract which can be considered as read-only
  """
  @spec read_functions_required_wallet(SmartContract.t()) :: [%{}]
  def read_functions_required_wallet(%SmartContract{abi: abi}) do
    case abi do
      nil ->
        []

      _ ->
        read_functions_required_wallet_from_abi(abi)
    end
  end

  def read_functions_required_wallet(nil), do: []

  def read_only_functions_from_abi_with_sender(abi, contract_address_hash, from, options \\ [])

  def read_only_functions_from_abi_with_sender([_ | _] = abi, contract_address_hash, from, options) do
    abi_with_method_id = get_abi_with_method_id(abi)

    abi_with_method_id
    |> Enum.filter(&Helper.queryable_method?(&1))
    |> fetch_current_values_from_blockchain(abi_with_method_id, contract_address_hash, false, options, from)
  end

  def read_only_functions_from_abi_with_sender(_, _, _, _), do: []

  def read_functions_required_wallet_from_abi([_ | _] = abi) do
    abi_with_method_id = get_abi_with_method_id(abi)

    abi_with_method_id
    |> Enum.reject(&Helper.queryable_method?(&1))
    |> Enum.filter(&Helper.read_with_wallet_method?(&1))
  end

  def read_functions_required_wallet_from_abi(_), do: []

  def get_abi_with_method_id(abi) do
    abi
    |> Enum.map(fn method ->
      with parsed_method <- [method] |> ABI.parse_specification() |> Enum.at(0),
           true <- is_map(parsed_method),
           method_id <- Map.get(parsed_method, :method_id),
           true <- !is_nil(method_id) do
        Map.put(method, "method_id", Base.encode16(method_id, case: :lower))
      else
        _ ->
          method
      end
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

  @spec fetch_current_values_from_blockchain(
          any(),
          [%{optional(binary()) => any()}],
          Explorer.Chain.Hash.t(),
          boolean(),
          keyword(),
          nil | binary()
        ) :: [SmartContract.function_description()]
  def fetch_current_values_from_blockchain(
        functions,
        abi,
        contract_address_hash,
        leave_error_as_map,
        options,
        from \\ nil
      ) do
    initial_methods_id_order = Enum.map(functions, &Map.get(&1, "method_id"))

    %{to_be_fetched: to_be_fetched, method_id_to_outputs: method_id_to_outputs, unchanged: unchanged} =
      Enum.reduce(
        functions,
        %{to_be_fetched: %{}, method_id_to_outputs: %{}, unchanged: %{}},
        fn function,
           %{
             to_be_fetched: to_be_fetched,
             unchanged: unchanged,
             method_id_to_outputs: method_id_to_outputs
           } ->
          case function do
            %{"inputs" => []} ->
              [%ABI.FunctionSelector{returns: returns, method_id: _method_id}] = ABI.parse_specification([function])

              outputs = extract_outputs(returns)

              %{
                to_be_fetched: Map.put(to_be_fetched, function["method_id"], function),
                unchanged: unchanged,
                method_id_to_outputs: Map.put(method_id_to_outputs, function["method_id"], {outputs, function})
              }

            _ ->
              %{
                to_be_fetched: to_be_fetched,
                unchanged:
                  Map.put(
                    unchanged,
                    function["method_id"],
                    Map.put(function, "abi_outputs", Map.get(function, "outputs", []))
                  ),
                method_id_to_outputs: method_id_to_outputs
              }
          end
        end
      )

    methods = to_be_fetched |> Enum.map(fn {method_id, _function} -> {method_id, []} end) |> Enum.into(%{})

    res =
      contract_address_hash
      |> query_verified_contract(methods, from, leave_error_as_map, abi, options)

    method_id_to_abi_with_fetched_value =
      res
      |> Enum.map(fn {method_id, _result} ->
        {outputs, function} = method_id_to_outputs[method_id]

        names = outputs_to_list(function["outputs"])

        outputs = link_outputs_and_values(res, outputs, method_id)
        function = to_be_fetched[method_id]

        {method_id,
         function
         |> Map.replace!("outputs", outputs)
         |> Map.put("abi_outputs", Map.get(function, "outputs", []))
         |> Map.put("names", names)}
      end)
      |> Enum.into(%{})

    Enum.map(initial_methods_id_order, fn method_id ->
      unchanged[method_id] || method_id_to_abi_with_fetched_value[method_id]
    end)
  end

  @doc """
    Method performs query of read functions of a smart contract.
    `type` could be :proxy or :regular
    `from` is a address of a function caller
  """
  @spec query_function_with_names(
          Hash.t(),
          %{method_id: String.t(), args: [term()] | nil},
          :regular | :proxy,
          String.t() | nil,
          [],
          boolean()
        ) :: %{:names => [any()], :output => [%{}]}
  def query_function_with_names(contract_address_hash, params, type, from, abi, leave_error_as_map, options \\ [])

  def query_function_with_names(
        contract_address_hash,
        %{method_id: method_id, args: args},
        :regular,
        from,
        abi,
        leave_error_as_map,
        options
      ) do
    outputs =
      query_function_with_custom_abi_inner(
        contract_address_hash,
        method_id,
        args || [],
        from,
        leave_error_as_map,
        abi,
        options
      )

    names = parse_names_from_abi(abi, method_id)
    %{output: outputs, names: names}
  end

  def query_function_with_names(
        contract_address_hash,
        %{method_id: method_id, args: args},
        :proxy,
        from,
        _abi,
        leave_error_as_map,
        options
      ) do
    abi = get_abi(contract_address_hash, :proxy, options)

    outputs =
      query_function_with_custom_abi_inner(
        contract_address_hash,
        method_id,
        args || [],
        from,
        leave_error_as_map,
        abi
      )

    names = parse_names_from_abi(abi, method_id)
    %{output: outputs, names: names}
  end

  @doc """
    Method performs query of read functions of a smart contract.
    `type` could be :proxy or :regular
    `from` is a address of a function caller
  """
  @spec query_function_with_names_custom_abi(
          Hash.t(),
          %{method_id: String.t(), args: [term()] | nil},
          String.t(),
          [%{}],
          Keyword.t()
        ) :: %{:names => [any()], :output => [%{}]}
  def query_function_with_names_custom_abi(
        contract_address_hash,
        %{method_id: method_id, args: args},
        from,
        custom_abi,
        options \\ []
      ) do
    outputs =
      query_function_with_custom_abi(
        contract_address_hash,
        %{method_id: method_id, args: args},
        from,
        true,
        custom_abi,
        options
      )

    names = parse_names_from_abi(custom_abi, method_id)
    %{output: outputs, names: names}
  end

  @doc """
  Fetches the blockchain value of a function that requires arguments.

  ! IMPORTANT: if you use several times query_function/(5,6) for the same smart contract it's recommended to use query_function_with_custom_abi/5 in order to avoid fetching the same smart contract from DB several times.
  """
  @spec query_function(
          Hash.t(),
          %{method_id: String.t(), args: [term()] | [] | nil},
          atom(),
          String.t() | nil,
          true | false,
          [api?]
        ) :: [
          %{}
        ]
  def query_function(
        contract_address_hash,
        %{method_id: method_id, args: args},
        type,
        from,
        leave_error_as_map,
        options \\ []
      ) do
    query_function_inner(contract_address_hash, method_id, args || [], type, from, leave_error_as_map, options)
  end

  @spec query_function_inner(Hash.t(), String.t(), [term()], atom(), String.t() | nil, true | false, [api?]) :: [%{}]
  defp query_function_inner(contract_address_hash, method_id, args, type, from, leave_error_as_map, options) do
    abi = get_abi(contract_address_hash, type, options)

    parsed_final_abi =
      abi
      |> ABI.parse_specification()

    case process_abi(parsed_final_abi, method_id) do
      %{outputs: outputs, method_id: method_id} ->
        query_contract_and_link_outputs(contract_address_hash, args, from, abi, outputs, method_id, leave_error_as_map)

      {:error, message} ->
        {:error, message}
    end
  end

  @spec query_function_with_custom_abi(
          Hash.t(),
          %{method_id: String.t(), args: [term()] | nil | []},
          String.t() | nil,
          true | false,
          [%{}],
          Keyword.t()
        ) :: [
          %{}
        ]
  def query_function_with_custom_abi(
        contract_address_hash,
        %{method_id: method_id, args: args},
        from,
        leave_error_as_map,
        custom_abi,
        options \\ []
      ) do
    query_function_with_custom_abi_inner(
      contract_address_hash,
      method_id,
      args || [],
      from,
      leave_error_as_map,
      custom_abi,
      options
    )
  end

  @spec query_function_with_custom_abi_inner(
          Hash.t(),
          String.t(),
          [term()],
          String.t() | nil,
          true | false,
          [%{}],
          Keyword.t()
        ) :: [
          %{}
        ]
  defp query_function_with_custom_abi_inner(
         contract_address_hash,
         method_id,
         args,
         from,
         leave_error_as_map,
         custom_abi,
         options \\ []
       ) do
    parsed_abi =
      custom_abi
      |> ABI.parse_specification()

    case process_abi(parsed_abi, method_id) do
      %{outputs: outputs, method_id: method_id} ->
        query_contract_and_link_outputs(
          contract_address_hash,
          args,
          from,
          custom_abi,
          outputs,
          method_id,
          leave_error_as_map,
          options
        )

      {:error, message} ->
        {:error, message}
    end
  end

  defp process_abi([], _method_id), do: nil

  defp process_abi(abi, method_id) do
    function_object = find_function_by_method(abi, method_id)

    if function_object do
      %ABI.FunctionSelector{returns: returns, method_id: method_id} = function_object
      outputs = extract_outputs(returns)

      %{outputs: outputs, method_id: method_id}
    else
      {:error, "method_id does not exist"}
    end
  end

  defp query_contract_and_link_outputs(
         contract_address_hash,
         args,
         from,
         abi,
         outputs,
         method_id,
         leave_error_as_map,
         options \\ []
       ) do
    contract_address_hash
    |> query_verified_contract(%{method_id => normalize_args(args)}, from, leave_error_as_map, abi, options)
    |> link_outputs_and_values(outputs, method_id)
  end

  defp get_abi(contract_address_hash, type, options) do
    {contract, _} = SmartContract.address_hash_to_smart_contract_with_bytecode_twin(contract_address_hash, options)

    if type == :proxy do
      Proxy.get_implementation_abi_from_proxy(contract, options)
    else
      contract.abi
    end
  end

  defp parse_names_from_abi(abi, method_id) do
    function =
      Enum.find(get_abi_with_method_id(abi), fn el -> el["type"] == "function" and el["method_id"] == method_id end)

    outputs_to_list(function["outputs"])
  end

  defp outputs_to_list(nil), do: []

  defp outputs_to_list([]), do: []

  defp outputs_to_list(outputs) do
    for el <- outputs do
      name = if validate_name(el["name"]), do: el["name"], else: el["internalType"]

      if Map.has_key?(el, "components") do
        [name] ++ [outputs_to_list(el["components"])]
      else
        name
      end
    end
  end

  defp validate_name(name), do: not is_nil(name) and String.length(name) > 0

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
    if is_map(args) do
      [res] = Enum.map(args, &parse_item/1)
      res
    else
      Enum.map(args, &parse_item/1)
    end
  end

  defp parse_item(nil), do: nil

  defp parse_item("true"), do: true
  defp parse_item("false"), do: false

  defp parse_item(item) when is_tuple(item) do
    item
    |> Tuple.to_list()
    |> Enum.map(fn value ->
      if is_list(value) do
        parse_item(value)
      else
        hex =
          value
          |> Base.encode16(case: :lower)

        "0x" <> hex
      end
    end)
  end

  defp parse_item(items) when is_list(items) do
    Enum.map(items, &parse_item/1)
  end

  defp parse_item(item) do
    response = Integer.parse(item)

    case response do
      {integer, ""} ->
        integer

      _ ->
        item
    end
  end

  def link_outputs_and_values(blockchain_values, outputs, method_id) do
    default_value = Enum.map(outputs, fn _ -> "" end)

    case Map.get(blockchain_values, method_id, {:ok, default_value}) do
      {:ok, value} ->
        for {output, index} <- Enum.with_index(outputs) do
          new_value(output, List.wrap(value), index)
        end

      {:error, message} ->
        {:error, message}
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

      values_array = if is_list(values_array), do: values_array, else: []

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

  defp new_value(%{"type" => :string} = output, [value], _index) do
    Map.put_new(output, "value", Encoder.unescape(value))
  end

  defp new_value(%{"type" => "string"} = output, [value], _index) do
    Map.put_new(output, "value", Encoder.unescape(value))
  end

  defp new_value(%{"type" => "tuple" <> _types = type} = output, values, index) do
    value = Enum.at(values, index)

    result =
      if String.ends_with?(type, "[]") do
        value
        |> Enum.map(fn tuple -> new_value(%{"type" => String.slice(type, 0..-3//1)}, [tuple], 0) end)
        |> flat_arrays_map()
      else
        value
        |> zip_tuple_values_with_types(type)
        |> Enum.map(fn {type, part_value} ->
          new_value(%{"type" => type}, [part_value], 0)
        end)
        |> flat_arrays_map()
        |> List.to_tuple()
      end

    Map.put_new(output, "value", result)
  end

  defp new_value(output, [value], _index) do
    Map.put_new(output, "value", value)
  end

  defp new_value(output, values, index) do
    Map.put_new(output, "value", Enum.at(values, index))
  end

  defp flat_arrays_map(%{"value" => value}) do
    flat_arrays_map(value)
  end

  defp flat_arrays_map(value) when is_list(value) do
    Enum.map(value, &flat_arrays_map/1)
  end

  defp flat_arrays_map(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> flat_arrays_map()
    |> List.to_tuple()
  end

  defp flat_arrays_map(value) do
    value
  end

  @spec zip_tuple_values_with_types(tuple, binary | tuple()) :: [{binary, any}]
  def zip_tuple_values_with_types(value, {:tuple, tuple_types}) do
    values_list =
      value
      |> Tuple.to_list()

    Enum.zip(tuple_types, values_list)
  end

  def zip_tuple_values_with_types(value, type) do
    types_string =
      type
      |> String.slice(6..-2//1)

    types =
      if String.trim(types_string) == "" do
        []
      else
        types_string
        |> String.graphemes()
      end

    tuple_types =
      types
      |> Enum.reduce(
        {[""], 0},
        fn
          ",", {types_acc, 0} ->
            {["" | types_acc], 0}

          char, {[acc | types_acc], bracket_stack} ->
            new_bracket_stack =
              case char do
                "[" -> bracket_stack + 1
                "]" -> bracket_stack - 1
                _ -> bracket_stack
              end

            {[acc <> char | types_acc], new_bracket_stack}
        end
      )
      |> elem(0)
      |> Enum.reverse()

    values_list =
      value
      |> Tuple.to_list()

    Enum.zip(tuple_types, values_list)
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
