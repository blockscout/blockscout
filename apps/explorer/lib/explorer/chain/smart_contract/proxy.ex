defmodule Explorer.Chain.SmartContract.Proxy do
  @moduledoc """
  Module for proxy smart-contract implementation detection
  """

  alias EthereumJSONRPC.Contract
  alias Explorer.Chain.{Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.{Basic, EIP1167, EIP1822, EIP1967, EIP930, MasterCopy}

  import Explorer.Chain,
    only: [
      string_to_address_hash: 1
    ]

  import Explorer.Chain.SmartContract, only: [burn_address_hash_string: 0, is_burn_signature_or_nil: 1]

  # supported signatures:
  # 5c60da1b = keccak256(implementation())
  @implementation_signature "5c60da1b"
  # aaf10f42 = keccak256(getImplementation())
  @get_implementation_signature "aaf10f42"
  # bb82aa5e = keccak256(comptrollerImplementation()) Compound protocol proxy pattern
  @comptroller_implementation_signature "bb82aa5e"
  # aaf10f42 = keccak256(getAddress(bytes32))
  @get_address_signature "21f8a721"

  @typep api? :: {:api?, true | false}

  @doc """
  Fetches into DB proxy contract implementation's address and name from different proxy patterns
  """
  @spec fetch_implementation_address_hash(Hash.Address.t(), list(), boolean() | nil, [api?]) ::
          {String.t() | nil, String.t() | nil}
  def fetch_implementation_address_hash(proxy_address_hash, proxy_abi, metadata_from_verified_twin, options)
      when not is_nil(proxy_address_hash) and not is_nil(proxy_abi) do
    implementation_address_hash_string = get_implementation_address_hash_string(proxy_address_hash, proxy_abi)

    SmartContract.save_implementation_data(
      implementation_address_hash_string,
      proxy_address_hash,
      metadata_from_verified_twin,
      options
    )
  end

  def fetch_implementation_address_hash(_, _, _, _) do
    {nil, nil}
  end

  @doc """
  Checks if smart-contract is proxy. Returns true/false.
  """
  @spec proxy_contract?(SmartContract.t(), any()) :: boolean()
  def proxy_contract?(smart_contract, options \\ []) do
    {:ok, burn_address_hash} = string_to_address_hash(SmartContract.burn_address_hash_string())

    if smart_contract.implementation_address_hash &&
         smart_contract.implementation_address_hash.bytes !== burn_address_hash.bytes do
      true
    else
      {implementation_address_hash_string, _} = SmartContract.get_implementation_address_hash(smart_contract, options)

      with false <- is_nil(implementation_address_hash_string),
           {:ok, implementation_address_hash} <- string_to_address_hash(implementation_address_hash_string),
           false <- implementation_address_hash.bytes == burn_address_hash.bytes do
        true
      else
        _ ->
          false
      end
    end
  end

  @doc """
  Decodes address output into 20 bytes address hash
  """
  @spec abi_decode_address_output(any()) :: nil | binary()
  def abi_decode_address_output(nil), do: nil

  def abi_decode_address_output("0x"), do: SmartContract.burn_address_hash_string()

  def abi_decode_address_output(address) when is_binary(address) do
    if String.length(address) > 42 do
      "0x" <> String.slice(address, -40, 40)
    else
      address
    end
  end

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
    {implementation_address_hash_string, _name} = SmartContract.get_implementation_address_hash(smart_contract, options)
    SmartContract.get_smart_contract_abi(implementation_address_hash_string)
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
  @spec get_implementation_from_storage(Hash.Address.t(), String.t(), any()) :: String.t() | nil
  def get_implementation_from_storage(proxy_address_hash, storage_slot, json_rpc_named_arguments) do
    case Contract.eth_get_storage_at_request(
           proxy_address_hash,
           storage_slot,
           nil,
           json_rpc_named_arguments
         ) do
      {:ok, empty_address_hash_string}
      when is_burn_signature_or_nil(empty_address_hash_string) ->
        nil

      {:ok, implementation_logic_address_hash_string} ->
        implementation_logic_address_hash_string

      _ ->
        nil
    end
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
  @spec get_implementation_address_hash_string_eip1167(Hash.Address.t(), any()) :: String.t() | nil
  def get_implementation_address_hash_string_eip1167(proxy_address_hash, proxy_abi) do
    get_implementation_address_hash_string_by_module(
      EIP1167,
      :get_implementation_address_hash_string_eip1967,
      [
        proxy_address_hash,
        proxy_abi
      ]
    )
  end

  @doc """
  Returns EIP-1967 implementation address or tries next proxy pattern
  """
  @spec get_implementation_address_hash_string_eip1967(Hash.Address.t(), any()) :: String.t() | nil
  def get_implementation_address_hash_string_eip1967(proxy_address_hash, proxy_abi) do
    get_implementation_address_hash_string_by_module(
      EIP1967,
      :get_implementation_address_hash_string_eip1822,
      [
        proxy_address_hash,
        proxy_abi
      ]
    )
  end

  @doc """
  Returns EIP-1822 implementation address or tries next proxy pattern
  """
  @spec get_implementation_address_hash_string_eip1822(Hash.Address.t(), any()) :: String.t() | nil
  def get_implementation_address_hash_string_eip1822(proxy_address_hash, proxy_abi) do
    get_implementation_address_hash_string_by_module(EIP1822, [proxy_address_hash, proxy_abi])
  end

  defp get_implementation_address_hash_string_by_module(
         module,
         next_func \\ :fallback_proxy_detection,
         [proxy_address_hash, _proxy_abi] = args
       ) do
    implementation_address_hash_string = module.get_implementation_address_hash_string(proxy_address_hash)

    if !is_nil(implementation_address_hash_string) && implementation_address_hash_string !== burn_address_hash_string() do
      implementation_address_hash_string
    else
      apply(__MODULE__, next_func, args)
    end
  end

  @spec fallback_proxy_detection(Hash.Address.t(), any()) :: String.t() | nil
  def fallback_proxy_detection(proxy_address_hash, proxy_abi) do
    implementation_method_abi = get_naive_implementation_abi(proxy_abi, "implementation")

    get_implementation_method_abi = get_naive_implementation_abi(proxy_abi, "getImplementation")

    comptroller_implementation_method_abi = get_naive_implementation_abi(proxy_abi, "comptrollerImplementation")

    master_copy_method_abi = get_master_copy_pattern(proxy_abi)

    get_address_method_abi = get_naive_implementation_abi(proxy_abi, "getAddress")

    cond do
      implementation_method_abi ->
        Basic.get_implementation_address_hash_string(@implementation_signature, proxy_address_hash, proxy_abi)

      get_implementation_method_abi ->
        Basic.get_implementation_address_hash_string(@get_implementation_signature, proxy_address_hash, proxy_abi)

      master_copy_method_abi ->
        MasterCopy.get_implementation_address_hash_string(proxy_address_hash)

      comptroller_implementation_method_abi ->
        Basic.get_implementation_address_hash_string(
          @comptroller_implementation_signature,
          proxy_address_hash,
          proxy_abi
        )

      get_address_method_abi ->
        EIP930.get_implementation_address_hash_string(@get_address_signature, proxy_address_hash, proxy_abi)

      true ->
        nil
    end
  end

  defp get_naive_implementation_abi(abi, getter_name) do
    abi
    |> Enum.find(fn method ->
      Map.get(method, "name") == getter_name && Map.get(method, "stateMutability") == "view"
    end)
  end

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
end
