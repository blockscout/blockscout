defmodule Explorer.Chain.SmartContract.Proxy do
  @moduledoc """
  Module for proxy smart-contract implementation detection
  """

  alias EthereumJSONRPC.Contract
  alias Explorer.Chain.{Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy

  alias Explorer.Chain.SmartContract.Proxy.{
    Basic,
    CloneWithImmutableArguments,
    EIP1167,
    EIP1822,
    EIP1967,
    EIP2535,
    EIP930,
    MasterCopy
  }

  import Explorer.Chain,
    only: [
      join_associations: 2,
      select_repo: 1,
      string_to_address_hash: 1
    ]

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0]

  import Explorer.Chain.SmartContract.Proxy.Models.Implementation,
    only: [
      is_burn_signature: 1,
      get_implementation: 2,
      get_proxy_implementations: 1,
      save_implementation_data: 4
    ]

  # supported signatures:
  # 5c60da1b = keccak256(implementation())
  @implementation_signature "5c60da1b"
  # aaf10f42 = keccak256(getImplementation())
  @get_implementation_signature "aaf10f42"
  # bb82aa5e = keccak256(comptrollerImplementation()) Compound protocol proxy pattern
  @comptroller_implementation_signature "bb82aa5e"
  # aaf10f42 = keccak256(getAddress(bytes32))
  @get_address_signature "21f8a721"

  @typep options :: [{:api?, true | false}, {:proxy_without_abi?, true | false}]

  @doc """
  Fetches into DB proxy contract implementation's address and name from different proxy patterns
  """
  @spec fetch_implementation_address_hash(Hash.Address.t(), list(), options) ::
          {[String.t()] | :empty | :error, [String.t()] | :empty | :error}
  def fetch_implementation_address_hash(proxy_address_hash, proxy_abi, options)
      when not is_nil(proxy_address_hash) do
    %{implementation_address_hash_strings: implementation_address_hash_strings, proxy_type: proxy_type} =
      if options[:proxy_without_abi?] do
        get_implementation_address_hash_string_for_non_verified_proxy(proxy_address_hash)
      else
        get_implementation_address_hash_string(proxy_address_hash, proxy_abi)
      end

    save_implementation_data(
      implementation_address_hash_strings,
      proxy_address_hash,
      proxy_type,
      options
    )
  end

  def fetch_implementation_address_hash(_, _, _) do
    {:empty, :empty}
  end

  @doc """
  Checks if smart-contract is proxy. Returns true/false.
  """
  @spec proxy_contract?(SmartContract.t(), Keyword.t()) :: boolean()
  def proxy_contract?(smart_contract, options \\ []) do
    {:ok, burn_address_hash} = string_to_address_hash(SmartContract.burn_address_hash_string())
    implementation = get_proxy_implementations(smart_contract.address_hash)

    with false <- is_nil(implementation),
         false <- Enum.empty?(implementation.address_hashes),
         implementation_address_hash = Enum.at(implementation.address_hashes, 0),
         false <- implementation_address_hash.bytes == burn_address_hash.bytes do
      true
    else
      _ ->
        {implementation_address_hash_strings, _implementation_names} = get_implementation(smart_contract, options)

        with false <- is_nil(implementation_address_hash_strings),
             false <- Enum.empty?(implementation_address_hash_strings) do
          implementation_address_hash_strings
          |> Enum.reduce_while(false, fn implementation_address_hash_string, acc ->
            with {:ok, implementation_address_hash} <- string_to_address_hash(implementation_address_hash_string),
                 false <- implementation_address_hash.bytes == burn_address_hash.bytes do
              {:halt, true}
            else
              _ ->
                {:cont, acc}
            end
          end)
        else
          _ ->
            false
        end
    end
  end

  @doc """
  Decodes address output into 20 bytes address hash
  """
  @spec abi_decode_address_output(any()) :: nil | :error | binary()
  def abi_decode_address_output(nil), do: nil

  def abi_decode_address_output("0x"), do: SmartContract.burn_address_hash_string()

  def abi_decode_address_output(address) when is_binary(address) do
    if String.length(address) > 42 do
      "0x" <> String.slice(address, -40, 40)
    else
      address
    end
  end

  def abi_decode_address_output(:error), do: :error

  def abi_decode_address_output(_), do: nil

  @doc """
  Gets implementation ABI for given proxy smart-contract
  """
  @spec get_implementation_abi_from_proxy(any(), any()) :: [map()]
  def get_implementation_abi_from_proxy(
        %SmartContract{address_hash: proxy_address_hash, abi: abi} = smart_contract,
        options
      )
      when not is_nil(proxy_address_hash) and not is_nil(abi) do
    {implementation_address_hash_strings, _names} = get_implementation(smart_contract, options)

    implementation_address_hash_strings
    |> Enum.reduce([], fn implementation_address_hash_string, acc ->
      SmartContract.get_smart_contract_abi(implementation_address_hash_string) ++ acc
    end)
  end

  def get_implementation_abi_from_proxy(_, _), do: []

  @doc """
  Checks if the ABI of the smart-contract follows GnosisSafe proxy pattern
  """
  @spec gnosis_safe_contract?([map()]) :: boolean()
  def gnosis_safe_contract?(abi) when not is_nil(abi) do
    if get_master_copy_pattern(abi), do: true, else: false
  end

  def gnosis_safe_contract?(abi) when is_nil(abi), do: false

  @doc """
  Checks if the input of the smart-contract follows master-copy (or Safe) proxy pattern before
  fetching its implementation from 0x0 storage pointer
  """
  @spec master_copy_pattern?(map()) :: any()
  def master_copy_pattern?(method) do
    Map.get(method, "type") == "constructor" &&
      method
      |> Enum.find(fn item ->
        case item do
          {"inputs", inputs} ->
            find_input_by_name(inputs, "_masterCopy") || find_input_by_name(inputs, "_singleton")

          _ ->
            false
        end
      end)
  end

  @doc """
  Gets implementation from proxy contract's specific storage
  """
  @spec get_implementation_from_storage(Hash.Address.t(), String.t(), any()) :: String.t() | :error | nil
  def get_implementation_from_storage(proxy_address_hash, storage_slot, json_rpc_named_arguments) do
    case Contract.eth_get_storage_at_request(
           proxy_address_hash,
           storage_slot,
           nil,
           json_rpc_named_arguments
         ) do
      {:ok, empty_address_hash_string}
      when is_burn_signature(empty_address_hash_string) ->
        nil

      {:ok, "0x" <> storage_value} ->
        extract_address_hex_from_storage_pointer(storage_value)

      {:error, _error} ->
        :error

      _ ->
        nil
    end
  end

  defp get_implementation_address_hash_string_for_non_verified_proxy(proxy_address_hash) do
    get_implementation_address_hash_string_eip1167(
      proxy_address_hash,
      nil,
      false
    )
  end

  defp get_implementation_address_hash_string(proxy_address_hash, proxy_abi) do
    get_implementation_address_hash_string_eip1167(
      proxy_address_hash,
      proxy_abi
    )
  end

  @doc """
  Returns EIP-1167 implementation address or tries next proxy pattern
  """
  @spec get_implementation_address_hash_string_eip1167(Hash.Address.t(), any(), bool()) ::
          %{implementation_address_hash_strings: [String.t() | :error | nil], proxy_type: atom()}
  def get_implementation_address_hash_string_eip1167(proxy_address_hash, proxy_abi, go_to_fallback? \\ true) do
    get_implementation_address_hash_string_by_module(
      EIP1167,
      :eip1167,
      [
        proxy_address_hash,
        proxy_abi,
        go_to_fallback?
      ],
      :get_implementation_address_hash_string_clones_with_immutable_arguments
    )
  end

  @doc """
  Returns implementation address by following "Clone with immutable arguments" pattern or tries next proxy pattern
  """
  @spec get_implementation_address_hash_string_clones_with_immutable_arguments(Hash.Address.t(), any(), bool()) ::
          %{implementation_address_hash_strings: [String.t()] | :error | nil, proxy_type: atom() | :unknown}
  def get_implementation_address_hash_string_clones_with_immutable_arguments(
        proxy_address_hash,
        proxy_abi,
        go_to_fallback? \\ true
      ) do
    get_implementation_address_hash_string_by_module(
      CloneWithImmutableArguments,
      :clone_with_immutable_arguments,
      [
        proxy_address_hash,
        proxy_abi,
        go_to_fallback?
      ],
      :get_implementation_address_hash_string_eip1967
    )
  end

  @doc """
  Returns EIP-1967 implementation address or tries next proxy pattern
  """
  @spec get_implementation_address_hash_string_eip1967(Hash.Address.t(), any(), bool()) :: %{
          implementation_address_hash_strings: [String.t() | :error | nil],
          proxy_type: atom()
        }
  def get_implementation_address_hash_string_eip1967(proxy_address_hash, proxy_abi, go_to_fallback?) do
    get_implementation_address_hash_string_by_module(
      EIP1967,
      :eip1967,
      [
        proxy_address_hash,
        proxy_abi,
        go_to_fallback?
      ],
      :get_implementation_address_hash_string_eip1822
    )
  end

  @doc """
  Returns EIP-1822 implementation address or tries next proxy pattern
  """
  @spec get_implementation_address_hash_string_eip1822(Hash.Address.t(), any(), bool()) :: %{
          implementation_address_hash_strings: [String.t() | :error | nil],
          proxy_type: atom()
        }
  def get_implementation_address_hash_string_eip1822(proxy_address_hash, proxy_abi, go_to_fallback?) do
    get_implementation_address_hash_string_by_module(EIP1822, :eip1822, [proxy_address_hash, proxy_abi, go_to_fallback?])
  end

  defp get_implementation_address_hash_string_by_module(
         module,
         proxy_type,
         [proxy_address_hash, proxy_abi, go_to_fallback?] = args,
         next_func \\ :fallback_proxy_detection
       ) do
    implementation_address_hash_string = module.get_implementation_address_hash_string(proxy_address_hash)

    if !is_nil(implementation_address_hash_string) && implementation_address_hash_string !== burn_address_hash_string() &&
         implementation_address_hash_string !== :error do
      %{implementation_address_hash_strings: [implementation_address_hash_string], proxy_type: proxy_type}
    else
      cond do
        next_func !== :fallback_proxy_detection ->
          apply(__MODULE__, next_func, args)

        go_to_fallback? && next_func == :fallback_proxy_detection ->
          fallback_value = implementation_fallback_value(implementation_address_hash_string)

          apply(__MODULE__, :fallback_proxy_detection, [proxy_address_hash, proxy_abi, fallback_value])

        true ->
          implementation_fallback_value(implementation_address_hash_string)
      end
    end
  end

  defp implementation_fallback_value(implementation_address_hash_string) do
    value = if implementation_address_hash_string == :error, do: :error, else: []

    %{implementation_address_hash_strings: value, proxy_type: :unknown}
  end

  @spec fallback_proxy_detection(Hash.Address.t(), any(), :error | nil) :: %{
          implementation_address_hash_strings: [String.t() | :error | nil],
          proxy_type: atom()
        }
  def fallback_proxy_detection(proxy_address_hash, proxy_abi, fallback_value \\ nil) do
    implementation_method_abi = get_naive_implementation_abi(proxy_abi, "implementation")

    get_implementation_method_abi = get_naive_implementation_abi(proxy_abi, "getImplementation")

    comptroller_implementation_method_abi = get_naive_implementation_abi(proxy_abi, "comptrollerImplementation")

    diamond_implementation_method_abi = get_naive_implementation_abi(proxy_abi, "facetAddresses")

    master_copy_method_abi = get_master_copy_pattern(proxy_abi)

    get_address_method_abi = get_naive_implementation_abi(proxy_abi, "getAddress")

    cond do
      diamond_implementation_method_abi ->
        implementation_address_hash_strings = EIP2535.get_implementation_address_hash_strings(proxy_address_hash)

        %{implementation_address_hash_strings: implementation_address_hash_strings, proxy_type: :eip2535}

      implementation_method_abi ->
        implementation_address_hash_string =
          Basic.get_implementation_address_hash_string(@implementation_signature, proxy_address_hash, proxy_abi)

        %{implementation_address_hash_strings: [implementation_address_hash_string], proxy_type: :basic_implementation}

      get_implementation_method_abi ->
        implementation_address_hash_string =
          Basic.get_implementation_address_hash_string(@get_implementation_signature, proxy_address_hash, proxy_abi)

        %{
          implementation_address_hash_strings: [implementation_address_hash_string],
          proxy_type: :basic_get_implementation
        }

      master_copy_method_abi ->
        implementation_address_hash_string = MasterCopy.get_implementation_address_hash_string(proxy_address_hash)
        %{implementation_address_hash_strings: [implementation_address_hash_string], proxy_type: :master_copy}

      comptroller_implementation_method_abi ->
        implementation_address_hash_string =
          Basic.get_implementation_address_hash_string(
            @comptroller_implementation_signature,
            proxy_address_hash,
            proxy_abi
          )

        %{implementation_address_hash_strings: [implementation_address_hash_string], proxy_type: :comptroller}

      get_address_method_abi ->
        implementation_address_hash_string =
          EIP930.get_implementation_address_hash_string(@get_address_signature, proxy_address_hash, proxy_abi)

        %{implementation_address_hash_strings: [implementation_address_hash_string], proxy_type: :eip_930}

      true ->
        fallback_value
    end
  end

  defp get_naive_implementation_abi(nil, _getter_name), do: nil

  defp get_naive_implementation_abi(abi, getter_name) do
    abi
    |> Enum.find(fn method ->
      Map.get(method, "name") == getter_name && Map.get(method, "stateMutability") == "view"
    end)
  end

  defp get_master_copy_pattern(nil), do: nil

  defp get_master_copy_pattern(abi) do
    abi
    |> Enum.find(fn method ->
      master_copy_pattern?(method)
    end)
  end

  @doc """
  Returns combined ABI from proxy and implementation smart-contracts
  """
  @spec combine_proxy_implementation_abi(any(), any()) :: SmartContract.abi()
  def combine_proxy_implementation_abi(smart_contract, options \\ [])

  def combine_proxy_implementation_abi(%SmartContract{abi: abi} = smart_contract, options) when not is_nil(abi) do
    implementation_abi = Proxy.get_implementation_abi_from_proxy(smart_contract, options)

    if Enum.empty?(implementation_abi), do: abi, else: implementation_abi ++ abi
  end

  def combine_proxy_implementation_abi(_, _) do
    []
  end

  defp find_input_by_name(inputs, name) do
    inputs
    |> Enum.find(fn input ->
      Map.get(input, "name") == name
    end)
  end

  @doc """
  Decodes 20 bytes address hex from smart-contract storage pointer value
  """
  @spec extract_address_hex_from_storage_pointer(binary) :: binary
  def extract_address_hex_from_storage_pointer(storage_value) when is_binary(storage_value) do
    address_hex = storage_value |> String.slice(-40, 40) |> String.pad_leading(40, ["0"])

    "0x" <> address_hex
  end

  @doc """
  implementation address hash to SmartContract
  """
  @spec implementation_to_smart_contract(nil | Hash.Address.t(), Keyword.t()) :: nil | SmartContract.t()
  def implementation_to_smart_contract(nil, _options), do: nil

  def implementation_to_smart_contract(address_hash, options) do
    necessity_by_association = %{
      :smart_contract_additional_sources => :optional
    }

    address_hash
    |> SmartContract.get_smart_contract_query()
    |> join_associations(necessity_by_association)
    |> select_repo(options).one(timeout: 10_000)
  end
end
