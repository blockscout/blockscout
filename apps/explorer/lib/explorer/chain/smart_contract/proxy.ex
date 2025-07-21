defmodule Explorer.Chain.SmartContract.Proxy do
  @moduledoc """
  Module for proxy smart-contract implementation detection
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  require Logger

  import EthereumJSONRPC, only: [id_to_params: 1, json_rpc: 2]

  alias EthereumJSONRPC.Contract
  alias Explorer.Chain.{Address, Data, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.Models.Implementation

  alias Explorer.Chain.SmartContract.Proxy.{
    BasicImplementationGetter,
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

  import Explorer.Chain,
    only: [
      join_associations: 2,
      select_repo: 1,
      string_to_address_hash: 1
    ]

  import Explorer.Chain.SmartContract.Proxy.Models.Implementation,
    only: [
      get_implementation: 2,
      get_proxy_implementations: 1,
      save_implementation_data: 2
    ]

  @bytecode_matching_proxy_types [
    {EIP1167, :eip1167},
    {EIP7702, :eip7702},
    {CloneWithImmutableArguments, :clone_with_immutable_arguments},
    {ResolvedDelegateProxy, :resolved_delegate_proxy},
    {MasterCopy, :master_copy},
    {ERC7760, :erc7760}
  ]

  @generic_proxy_types [
    {EIP1967, :eip1967},
    {EIP1967, :eip1967_oz},
    {EIP1967, :eip1967_beacon},
    {EIP1822, :eip1822},
    {EIP2535, :eip2535},
    {BasicImplementationGetter, :implementation},
    {BasicImplementationGetter, :get_implementation},
    {BasicImplementationGetter, :comptroller_implementation}
  ]

  @zero_address_hash_string "0x0000000000000000000000000000000000000000"
  @zero_bytes32_string "0x0000000000000000000000000000000000000000000000000000000000000000"

  @type options :: [{:api?, true | false}]

  @type prefetch_requirement :: {:storage | :call, String.t()}
  @type prefetched_values :: %{prefetch_requirement() => String.t() | nil}

  @spec zero_hex_string?(any()) :: boolean()
  defp zero_hex_string?(term), do: term in ["0x", "0x0", @zero_address_hash_string, @zero_bytes32_string]

  @doc """
  Fetches into DB proxy contract implementation's address and name from different proxy patterns
  """
  @spec fetch_implementation_address_hash(Hash.Address.t() | nil, options()) :: Implementation.t() | :empty | :error
  def fetch_implementation_address_hash(proxy_address_hash, options)
      when not is_nil(proxy_address_hash) do
    proxy_address = Address.get(proxy_address_hash, options)

    case try_to_get_implementation_from_known_proxy_patterns(proxy_address) do
      :empty -> :empty
      :error -> :error
      proxy_implementations -> save_implementation_data(proxy_implementations, options)
    end
  end

  def fetch_implementation_address_hash(_, _) do
    :empty
  end

  @doc """
  Checks if smart-contract is proxy. Returns true/false.
  """
  @spec proxy_contract?(SmartContract.t(), Keyword.t()) :: boolean()
  def proxy_contract?(smart_contract, options \\ []) do
    proxy_implementations = get_proxy_implementations(smart_contract.address_hash)

    if !is_nil(proxy_implementations) and !Enum.empty?(proxy_implementations.address_hashes) do
      true
    else
      implementation = get_implementation(smart_contract, options)

      !is_nil(implementation) and !Enum.empty?(implementation.address_hashes)
    end
  end

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
  Tries to get implementation address from known proxy patterns
  """
  @spec try_to_get_implementation_from_known_proxy_patterns(Address.t()) ::
          %{
            proxy_address_hash: Hash.Address.t(),
            address_hashes: [Hash.Address.t()],
            proxy_type: atom() | nil,
            alternative_proxy_types: [atom()] | nil,
            alternative_address_hashes: [[Hash.Address.t()]] | nil
          }
          | :error
          | :empty
  def try_to_get_implementation_from_known_proxy_patterns(proxy_address) do
    with true <- Address.smart_contract?(proxy_address),
         bytecode_matching_result =
           Enum.find_value(@bytecode_matching_proxy_types, fn {module, proxy_type} ->
             case module.match_bytecode_and_resolve_implementation(proxy_address) do
               nil ->
                 nil

               :error ->
                 :error

               implementation_address_hash ->
                 %{
                   proxy_address_hash: proxy_address.hash,
                   address_hashes: [implementation_address_hash],
                   proxy_type: proxy_type,
                   alternative_proxy_types: nil,
                   alternative_address_hashes: nil
                 }
             end
           end),
         {:bytecode_matching_result, nil} <- {:bytecode_matching_result, bytecode_matching_result},
         {:ok, prefetched_values} <- prefetch_values(proxy_address),
         [{main_proxy_type, main_implementation_address_hashes} | rest] <-
           @generic_proxy_types
           |> Enum.map(fn {module, proxy_type} ->
             case module.resolve_implementations(proxy_address, proxy_type, prefetched_values) do
               nil ->
                 nil

               :error ->
                 Logger.warning(
                   "Failed to resolve implementations for proxy address #{proxy_address.hash} and proxy type #{proxy_type}"
                 )

                 nil

               implementation_address_hashes ->
                 {proxy_type, implementation_address_hashes}
             end
           end)
           |> Enum.reject(&is_nil/1) do
      main_implementation_address_hashes_sorted = main_implementation_address_hashes |> Enum.sort()

      {alternative_proxy_types, alternative_address_hashes} =
        if rest |> Enum.all?(&(&1 |> elem(1) |> Enum.sort() == main_implementation_address_hashes_sorted)) do
          {nil, nil}
        else
          Enum.unzip(rest)
        end

      %{
        proxy_address_hash: proxy_address.hash,
        address_hashes: main_implementation_address_hashes,
        proxy_type: main_proxy_type,
        alternative_proxy_types: alternative_proxy_types,
        alternative_address_hashes: alternative_address_hashes
      }
    else
      {:bytecode_matching_result, %{} = result} -> result
      :error -> :error
      _ -> :empty
    end
  end

  @spec prefetch_values(Address.t()) :: {:ok, prefetched_values()} | :error
  defp prefetch_values(proxy_address) do
    @generic_proxy_types
    |> Enum.flat_map(fn {module, proxy_type} -> module.get_prefetch_requirements(proxy_address, proxy_type) end)
    |> fetch_values(proxy_address.hash)
  end

  @spec fetch_values([prefetch_requirement()], Hash.Address.t()) :: {:ok, prefetched_values()} | :error
  def fetch_values(reqs, address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    id_to_params = id_to_params(reqs)

    with {:ok, responses} <-
           id_to_params
           |> Enum.map(fn {index, req} -> encode_request(req, address_hash, index) end)
           |> json_rpc(json_rpc_named_arguments),
         fetched_values when is_map(fetched_values) <-
           Enum.reduce_while(responses, %{}, fn
             %{id: id} = result, acc ->
               {:cont, Map.put(acc, id_to_params[id], Map.get(result, :result))}

             _, _ ->
               {:halt, :error}
           end) do
      {:ok, fetched_values}
    else
      _ -> :error
    end
  end

  @spec fetch_value(prefetch_requirement(), Hash.Address.t(), prefetched_values() | nil) ::
          {:ok, String.t() | nil} | :error
  def fetch_value(req, address_hash, prefetch_values \\ nil)

  def fetch_value(req, address_hash, nil) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    case req |> encode_request(address_hash, 0) |> json_rpc(json_rpc_named_arguments) do
      {:ok, response} -> {:ok, response}
      _ -> :error
    end
  end

  def fetch_value(req, _address_hash, prefetch_values) do
    prefetch_values |> Map.fetch(req)
  end

  defp encode_request({:storage, value}, address_hash, index),
    do: Contract.eth_get_storage_at_request(address_hash, value, index)

  defp encode_request({:call, value}, address_hash, index),
    do: Contract.eth_call_request(value, address_hash, index, nil, nil)

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
  Decodes non-zero address hash from raw smart-contract hex response
  """
  @spec extract_address_hash(String.t() | nil) :: {:ok, Hash.Address.t()} | :error | nil
  def extract_address_hash(value) do
    with false <- is_nil(value),
         false <- zero_hex_string?(value),
         {:ok, %Data{bytes: bytes}} <- Data.cast(value) do
      Hash.Address.cast((<<0::160>> <> bytes) |> binary_slice(-20, 20))
    else
      :error -> :error
      _ -> nil
    end
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
  Retrieves formatted proxy implementation objects with addresses and names.

  ## Parameters

    * `proxy_implementation` - An `Implementation.t()` struct.

  ## Returns

  A list of maps containing information about the proxy implementations.

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
            %{
              "address_hash" => Address.checksum(address_hash),
              "name" => name
            }
            |> chain_type_fields(implementations_info)
            | acc
          ]

        _ ->
          with {:ok, address_hash} <- string_to_address_hash(address),
               checksummed_address <- Address.checksum(address_hash) do
            [
              %{"address_hash" => checksummed_address, "name" => name}
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
    def chain_type_fields(%{"address_hash" => address_hash} = address, implementations_info) do
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

  def alternative_implementations_info(proxy_implementation) do
    if proxy_implementation &&
         proxy_implementation.alternative_proxy_types &&
         proxy_implementation.alternative_address_hashes do
      proxy_implementation.alternative_proxy_types
      |> Enum.zip(proxy_implementation.alternative_address_hashes)
      |> Enum.map(fn {proxy_type, address_hashes} ->
        %{
          "proxy_type" => proxy_type,
          "address_hashes" => Enum.map(address_hashes, &Address.checksum/1)
        }
      end)
    else
      nil
    end
  end
end
