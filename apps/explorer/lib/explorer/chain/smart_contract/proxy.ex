defmodule Explorer.Chain.SmartContract.Proxy do
  @moduledoc """
  Module for proxy smart-contract implementation detection
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias EthereumJSONRPC.Contract
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

  alias Explorer.Chain.SmartContract.Proxy.{
    CloneWithImmutableArguments,
    EIP1167,
    EIP1822,
    EIP1967,
    EIP2535,
    EIP7702,
    ERC7760,
    MasterCopy,
    ResolvedDelegateProxy
  }

  alias Explorer.SmartContract.Helper, as: SmartContractHelper

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

  @typep options :: [{:api?, true | false}, {:proxy_without_abi?, true | false}]

  @doc """
  Fetches into DB proxy contract implementation's address and name from different proxy patterns
  """
  @spec fetch_implementation_address_hash(Hash.Address.t(), list(), options) ::
          Implementation.t() | :empty | :error
  def fetch_implementation_address_hash(proxy_address_hash, proxy_abi, options)
      when not is_nil(proxy_address_hash) do
    %{implementation_address_hash_strings: implementation_address_hash_strings, proxy_type: proxy_type} =
      try_to_get_implementation_from_known_proxy_patterns(
        proxy_address_hash,
        proxy_abi,
        options[:proxy_without_abi?]
      )

    save_implementation_data(
      implementation_address_hash_strings,
      proxy_address_hash,
      proxy_type,
      options
    )
  end

  def fetch_implementation_address_hash(_, _, _) do
    :empty
  end

  @doc """
  Checks if smart-contract is proxy. Returns true/false.
  """
  @spec proxy_contract?(SmartContract.t(), Keyword.t()) :: boolean()
  def proxy_contract?(smart_contract, options \\ []) do
    {:ok, burn_address_hash} = string_to_address_hash(SmartContract.burn_address_hash_string())
    proxy_implementations = get_proxy_implementations(smart_contract.address_hash)

    with false <- is_nil(proxy_implementations),
         false <- Enum.empty?(proxy_implementations.address_hashes),
         implementation_address_hash = Enum.at(proxy_implementations.address_hashes, 0),
         false <- implementation_address_hash.bytes == burn_address_hash.bytes do
      true
    else
      _ ->
        implementation = get_implementation(smart_contract, options)

        with false <- is_nil(implementation),
             false <- Enum.empty?(implementation.address_hashes) do
          has_not_burn_address_hash?(implementation.address_hashes, burn_address_hash)
        else
          _ ->
            false
        end
    end
  end

  @spec has_not_burn_address_hash?([Hash.Address.t()], Hash.Address.t()) :: boolean()
  defp has_not_burn_address_hash?(address_hashes, burn_address_hash) do
    address_hashes
    |> Enum.reduce_while(false, fn implementation_address_hash, acc ->
      if implementation_address_hash.bytes == burn_address_hash.bytes, do: {:cont, acc}, else: {:halt, true}
    end)
  end

  @doc """
    Decodes and formats an address output from a smart contract ABI.

    This function handles various input formats and edge cases when decoding
    address outputs from smart contract function calls or events.

    ## Parameters
    - `address`: The address output to decode. Can be `nil`, `"0x"`, a binary string, or `:error`.

    ## Returns
    - `nil` if the input is `nil`.
    - The burn address hash string if the input is `"0x"`.
    - A formatted address string if the input is a valid binary string.
    - `:error` if the input is `:error`.
    - `nil` for any other input type.
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
    implementation = get_implementation(smart_contract, options)

    ((implementation && implementation.address_hashes) ||
       [])
    |> Enum.reduce([], fn implementation_address_hash, acc ->
      SmartContract.get_abi(implementation_address_hash) ++ acc
    end)
  end

  def get_implementation_abi_from_proxy(_, _), do: []

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

  @doc """
  Tries to get implementation address from known proxy patterns
  """
  @spec try_to_get_implementation_from_known_proxy_patterns(Hash.Address.t(), list() | nil, bool()) ::
          %{implementation_address_hash_strings: [String.t()] | :error, proxy_type: atom()}

  def try_to_get_implementation_from_known_proxy_patterns(proxy_address_hash, proxy_abi, proxy_without_abi?)
      when not is_nil(proxy_abi) or proxy_without_abi? == true do
    functions =
      [
        :get_implementation_address_hash_string_eip1167,
        :get_implementation_address_hash_string_eip7702,
        :get_implementation_address_hash_string_clones_with_immutable_arguments,
        :get_implementation_address_hash_string_eip1967,
        :get_implementation_address_hash_string_eip1822,
        :get_implementation_address_hash_string_eip2535,
        :get_implementation_address_hash_string_erc7760,
        :get_implementation_address_hash_string_resolved_delegate_proxy
      ]

    %{implementation_address_hash_strings: implementation_address_hash_strings, proxy_type: proxy_type} =
      functions
      |> Enum.reduce_while(nil, fn fun, _acc ->
        %{
          implementation_address_hash_strings: implementation_address_hash_strings,
          proxy_type: _proxy_type
        } = result = apply(__MODULE__, fun, [proxy_address_hash])

        case implementation_address_hash_strings do
          [] -> {:cont, result}
          :error -> {:halt, result}
          _ -> {:halt, result}
        end
      end)

    cond do
      implementation_address_hash_strings == :error ->
        fallback_proxy_detection(proxy_address_hash, proxy_abi, implementation_address_hash_strings_fallback(:error))

      implementation_address_hash_strings == [] ||
          implementation_address_hash_strings == [burn_address_hash_string()] ->
        fallback_proxy_detection(proxy_address_hash, proxy_abi, implementation_address_hash_strings_fallback(nil))

      true ->
        %{implementation_address_hash_strings: implementation_address_hash_strings, proxy_type: proxy_type}
    end
  end

  def try_to_get_implementation_from_known_proxy_patterns(proxy_address_hash, proxy_abi, _proxy_without_abi?) do
    fallback_proxy_detection(proxy_address_hash, proxy_abi, implementation_address_hash_strings_fallback(nil))
  end

  @spec get_implementation_address_hash_string_eip1167(Hash.Address.t()) ::
          %{implementation_address_hash_strings: [String.t() | :error | nil], proxy_type: atom()}
  def get_implementation_address_hash_string_eip1167(proxy_address_hash) do
    get_implementation_address_hash_string_by_module(EIP1167, :eip1167, proxy_address_hash)
  end

  @spec get_implementation_address_hash_string_clones_with_immutable_arguments(Hash.Address.t()) ::
          %{implementation_address_hash_strings: [String.t()] | :error, proxy_type: atom()}
  def get_implementation_address_hash_string_clones_with_immutable_arguments(proxy_address_hash) do
    get_implementation_address_hash_string_by_module(
      CloneWithImmutableArguments,
      :clone_with_immutable_arguments,
      proxy_address_hash
    )
  end

  @spec get_implementation_address_hash_string_eip7702(Hash.Address.t()) ::
          %{implementation_address_hash_strings: [String.t()] | :error, proxy_type: atom()}
  def get_implementation_address_hash_string_eip7702(proxy_address_hash) do
    get_implementation_address_hash_string_by_module(EIP7702, :eip7702, proxy_address_hash)
  end

  @spec get_implementation_address_hash_string_eip1967(Hash.Address.t()) :: %{
          implementation_address_hash_strings: [String.t() | :error | nil],
          proxy_type: atom()
        }
  def get_implementation_address_hash_string_eip1967(proxy_address_hash) do
    get_implementation_address_hash_string_by_module(EIP1967, :eip1967, proxy_address_hash)
  end

  @spec get_implementation_address_hash_string_eip1822(Hash.Address.t()) :: %{
          implementation_address_hash_strings: [String.t() | :error | nil],
          proxy_type: atom()
        }
  def get_implementation_address_hash_string_eip1822(proxy_address_hash) do
    get_implementation_address_hash_string_by_module(EIP1822, :eip1822, proxy_address_hash)
  end

  @spec get_implementation_address_hash_string_eip2535(Hash.Address.t()) :: %{
          implementation_address_hash_strings: [String.t() | :error | nil],
          proxy_type: atom()
        }
  def get_implementation_address_hash_string_eip2535(proxy_address_hash) do
    get_implementation_address_hash_string_by_module(EIP2535, :eip2535, proxy_address_hash)
  end

  @spec get_implementation_address_hash_string_erc7760(Hash.Address.t()) :: %{
          implementation_address_hash_strings: [String.t() | :error | nil],
          proxy_type: atom()
        }
  def get_implementation_address_hash_string_erc7760(proxy_address_hash) do
    get_implementation_address_hash_string_by_module(ERC7760, :erc7760, proxy_address_hash)
  end

  @spec get_implementation_address_hash_string_resolved_delegate_proxy(Hash.Address.t()) ::
          %{implementation_address_hash_strings: [String.t() | :error | nil], proxy_type: atom()}
  def get_implementation_address_hash_string_resolved_delegate_proxy(proxy_address_hash) do
    get_implementation_address_hash_string_by_module(
      ResolvedDelegateProxy,
      :resolved_delegate_proxy,
      proxy_address_hash
    )
  end

  defp get_implementation_address_hash_string_by_module(
         module,
         proxy_type,
         proxy_address_hash
       ) do
    implementation_address_hash_strings = module.get_implementation_address_hash_strings(proxy_address_hash, api?: true)

    if implementation_address_hash_strings == [] ||
         implementation_address_hash_strings == [burn_address_hash_string()] ||
         implementation_address_hash_strings == :error do
      implementation_address_hash_strings_fallback(implementation_address_hash_strings)
    else
      %{
        implementation_address_hash_strings: implementation_address_hash_strings,
        proxy_type: proxy_type
      }
    end
  end

  defp implementation_address_hash_strings_fallback(implementation_value) do
    value = if implementation_value == :error, do: :error, else: []

    %{implementation_address_hash_strings: value, proxy_type: :unknown}
  end

  @spec fallback_proxy_detection(Hash.Address.t(), list() | nil, %{
          implementation_address_hash_strings: [String.t()] | :error,
          proxy_type: atom()
        }) :: %{
          implementation_address_hash_strings: [String.t()] | :error,
          proxy_type: atom()
        }
  defp fallback_proxy_detection(proxy_address_hash, proxy_abi, fallback_value) do
    proxy_type = define_fallback_proxy_type(proxy_abi)

    case proxy_type do
      :implementation ->
        implementation_address_hash_string =
          SmartContractHelper.get_binary_string_from_contract_getter(
            @implementation_signature,
            to_string(proxy_address_hash),
            proxy_abi
          )

        %{
          implementation_address_hash_strings:
            implementation_address_hash_string_to_list(implementation_address_hash_string),
          proxy_type: :basic_implementation
        }

      :get_implementation ->
        implementation_address_hash_string =
          SmartContractHelper.get_binary_string_from_contract_getter(
            @get_implementation_signature,
            to_string(proxy_address_hash),
            proxy_abi
          )

        %{
          implementation_address_hash_strings:
            implementation_address_hash_string_to_list(implementation_address_hash_string),
          proxy_type: :basic_get_implementation
        }

      :master_copy ->
        implementation_address_hash_string = MasterCopy.get_implementation_address_hash_string(proxy_address_hash)

        %{
          implementation_address_hash_strings:
            implementation_address_hash_string_to_list(implementation_address_hash_string),
          proxy_type: :master_copy
        }

      :comptroller ->
        implementation_address_hash_string =
          SmartContractHelper.get_binary_string_from_contract_getter(
            @comptroller_implementation_signature,
            proxy_address_hash,
            proxy_abi
          )

        %{
          implementation_address_hash_strings:
            implementation_address_hash_string_to_list(implementation_address_hash_string),
          proxy_type: :comptroller
        }

      _ ->
        fallback_value
    end
  end

  defp implementation_address_hash_string_to_list(implementation_address_hash_string) do
    case implementation_address_hash_string do
      :error -> :error
      nil -> []
      hash -> [hash]
    end
  end

  defp define_fallback_proxy_type(nil), do: nil

  defp define_fallback_proxy_type(proxy_abi) do
    methods_to_proxy_types = %{
      "implementation" => :implementation,
      "getImplementation" => :get_implementation,
      "comptrollerImplementation" => :comptroller,
      "facetAddresses" => :diamond
    }

    proxy_abi
    |> Enum.reduce_while(nil, fn method, acc ->
      cond do
        Map.get(method, "name") in Map.keys(methods_to_proxy_types) && Map.get(method, "stateMutability") == "view" ->
          {:halt, methods_to_proxy_types[Map.get(method, "name")]}

        MasterCopy.pattern?(method) ->
          {:halt, :master_copy}

        true ->
          {:cont, acc}
      end
    end)
  end

  @doc """
  Returns combined ABI from proxy and implementation smart-contracts
  """
  @spec combine_proxy_implementation_abi(any(), any()) :: SmartContract.abi()
  def combine_proxy_implementation_abi(
        smart_contract,
        options \\ []
      ) do
    proxy_abi = (smart_contract && smart_contract.abi) || []
    implementation_abi = Proxy.get_implementation_abi_from_proxy(smart_contract, options)

    proxy_abi ++ implementation_abi
  end

  @doc """
  Decodes 20 bytes address hex from smart-contract storage pointer value
  """
  @spec extract_address_hex_from_storage_pointer(binary()) :: binary()
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
    |> SmartContract.get_by_address_hash_query()
    |> join_associations(necessity_by_association)
    |> select_repo(options).one(timeout: 10_000)
  end

  @doc """
  Retrieves formatted proxy object based on its implementation addresses and names.

  ## Parameters

    * `implementation_addresses` - A list of implementation addresses for the proxy object.
    * `implementation_names` - A list of implementation names for the proxy object.

  ## Returns

  A list of maps containing information about the proxy object.

  """
  @spec proxy_object_info(Implementation.t() | nil) :: [map()]
  def proxy_object_info(nil), do: []

  def proxy_object_info(proxy_implementation) do
    implementations_info = prepare_implementations(proxy_implementation)
    implementation_addresses = proxy_implementation.address_hashes
    implementation_names = proxy_implementation.names

    implementation_addresses
    |> Enum.zip(implementation_names)
    |> Enum.reduce([], fn {address, name}, acc ->
      case address do
        %Hash{} = address_hash ->
          [
            # todo: "address" should be removed in favour `address_hash` property with the next release after 8.0.0 + UPDATE PATTERN MATCHING in `chain_type_fields()` function
            %{
              "address_hash" => Address.checksum(address_hash),
              "address" => Address.checksum(address_hash),
              "name" => name
            }
            |> chain_type_fields(implementations_info)
            | acc
          ]

        _ ->
          with {:ok, address_hash} <- string_to_address_hash(address),
               checksummed_address <- Address.checksum(address_hash) do
            [
              # todo: "address" should be removed in favour `address_hash` property with the next release after 8.0.0 + UPDATE PATTERN MATCHING in `chain_type_fields()` function
              %{"address_hash" => checksummed_address, "address" => checksummed_address, "name" => name}
              |> chain_type_fields(implementations_info)
              | acc
            ]
          else
            _ -> acc
          end
      end
    end)
  end

  if @chain_type == :filecoin do
    def chain_type_fields(%{"address" => address_hash} = address, implementations_info) do
      Map.put(address, "filecoin_robust_address", implementations_info[address_hash])
    end

    def prepare_implementations(%Implementation{addresses: [_ | _] = addresses}) do
      Enum.into(addresses, %{}, fn address -> {Address.checksum(address.hash), address.filecoin_robust} end)
    end

    def prepare_implementations(_) do
      %{}
    end
  else
    def chain_type_fields(address, _proxy_implementations) do
      address
    end

    def prepare_implementations(_implementations_info) do
      :ignore
    end
  end
end
