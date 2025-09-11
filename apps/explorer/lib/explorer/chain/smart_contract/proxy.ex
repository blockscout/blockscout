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
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

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
      select_repo: 1
    ]

  import Explorer.Chain.SmartContract.Proxy.Models.Implementation,
    only: [
      get_implementation: 2,
      get_proxy_implementations: 1,
      save_implementation_data: 2
    ]

  @proxy_resolvers [
    # bytecode-matching proxy types
    {EIP1167, :eip1167},
    {EIP7702, :eip7702},
    {MasterCopy, :master_copy},
    {ERC7760, :erc7760},
    {CloneWithImmutableArguments, :clone_with_immutable_arguments},
    {ResolvedDelegateProxy, :resolved_delegate_proxy},

    # generic proxy types
    {EIP1967, :eip1967},
    {EIP1822, :eip1822},
    {EIP1967, :eip1967_beacon},
    {EIP2535, :eip2535},
    {EIP1967, :eip1967_oz},
    {BasicImplementationGetter, :basic_implementation},
    {BasicImplementationGetter, :basic_get_implementation},
    {BasicImplementationGetter, :comptroller}
  ]

  @zero_address_hash_string "0x0000000000000000000000000000000000000000"
  @zero_bytes32_string "0x0000000000000000000000000000000000000000000000000000000000000000"

  @type options :: [{:api?, true | false}]

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

  ## Parameters
  - `proxy_address`: The address to try to detect implementations for.

  ## Returns
  - Pre-filled `proxy_implementations` if the result should be saved to the database.
  - `:error` if the implementation detection failed, nothing should be saved to the database.
  - `:empty` if the address is empty or not a smart contract, nothing should be saved to the database.
  """
  @spec try_to_get_implementation_from_known_proxy_patterns(Address.t()) ::
          %{
            proxy_address_hash: Hash.Address.t(),
            address_hashes: [Hash.Address.t()],
            proxy_type: atom() | nil,
            conflicting_proxy_types: [atom()] | nil,
            conflicting_address_hashes: [[Hash.Address.t()]] | nil
          }
          | :error
          | :empty
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def try_to_get_implementation_from_known_proxy_patterns(proxy_address) do
    with true <- Address.smart_contract?(proxy_address),
         # first, we try to immediately resolve proxy types by matching bytecodes,
         # while collecting fetch requirements for all other proxy types
         resolvers_and_requirements when is_list(resolvers_and_requirements) <-
           Enum.reduce_while(@proxy_resolvers, [], fn {module, proxy_type}, acc ->
             case module.quick_resolve_implementations(proxy_address, proxy_type) do
               {:ok, address_hashes} ->
                 filtered_address_hashes = address_hashes |> Enum.reject(&(&1 == proxy_address.hash))

                 if Enum.empty?(filtered_address_hashes) do
                   {:halt,
                    %{
                      proxy_address_hash: proxy_address.hash,
                      address_hashes: []
                    }}
                 else
                   {:halt,
                    %{
                      proxy_address_hash: proxy_address.hash,
                      address_hashes: filtered_address_hashes,
                      proxy_type: proxy_type
                    }}
                 end

               {:cont, requirements} ->
                 {:cont, [{{module, proxy_type}, requirements} | acc]}

               :error ->
                 Logger.error(
                   "Failed to quick resolve implementations for proxy address #{proxy_address.hash} and proxy type #{proxy_type}"
                 )

                 {:halt, :error}

               _ ->
                 {:cont, acc}
             end
           end),
         # didn't match any known bytecode pattern, proceed with fetching required values
         {:ok, resolvers_and_fetched_values} <-
           resolvers_and_requirements
           |> Enum.reverse()
           |> prefetch_values(proxy_address.hash),
         generic_results when is_list(generic_results) <-
           Enum.reduce_while(resolvers_and_fetched_values, [], fn {{module, proxy_type}, values}, acc ->
             case module.resolve_implementations(proxy_address, proxy_type, values) do
               {:ok, implementation_address_hashes} ->
                 filtered_address_hashes = implementation_address_hashes |> Enum.reject(&(&1 == proxy_address.hash))

                 # credo:disable-for-next-line Credo.Check.Refactor.Nesting
                 if Enum.empty?(filtered_address_hashes) do
                   {:cont, acc}
                 else
                   {:cont, [{proxy_type, filtered_address_hashes} | acc]}
                 end

               :error ->
                 Logger.error(
                   "Failed to resolve implementations for proxy address #{proxy_address.hash} and proxy type #{proxy_type}"
                 )

                 {:halt, :error}

               _ ->
                 {:cont, acc}
             end
           end) do
      {address_hashes, proxy_type, conflicting_proxy_types, conflicting_address_hashes} =
        case Enum.reverse(generic_results) do
          [] ->
            {[], nil, nil, nil}

          [{proxy_type, address_hashes}] ->
            {address_hashes, proxy_type, nil, nil}

          [{proxy_type, address_hashes} | rest] ->
            address_hashes_sorted = address_hashes |> Enum.sort()

            if Enum.all?(rest, &(&1 |> elem(1) |> Enum.sort() == address_hashes_sorted)) do
              {address_hashes, proxy_type, nil, nil}
            else
              {conflicting_proxy_types, conflicting_address_hashes} = Enum.unzip(rest)
              {address_hashes, proxy_type, conflicting_proxy_types, conflicting_address_hashes}
            end
        end

      %{
        proxy_address_hash: proxy_address.hash,
        address_hashes: address_hashes,
        proxy_type: proxy_type,
        conflicting_proxy_types: conflicting_proxy_types,
        conflicting_address_hashes: conflicting_address_hashes
      }
    else
      %{proxy_type: _} = result -> result
      :error -> :error
      _ -> :empty
    end
  end

  @doc """
  Fetches all required eth_getStorageAt and eth_call results for given proxy resolvers and requirements.

  ## Parameters
  - `resolvers_and_requirements`: The list of proxy resolvers and their requirements.
  - `address_hash`: The address hash to fetch the values for.

  ## Returns
  - `{:ok, [{any(), ResolverBehaviour.fetched_values()}]}` if all of the values are fetched successfully,
    map can contain nil values for failed/reverted eth_call requests.
  - `:error` if the prefetching failed.
  """
  @spec prefetch_values([{any(), ResolverBehaviour.fetch_requirements()}], Hash.Address.t()) ::
          {:ok, [{any(), ResolverBehaviour.fetched_values()}]} | :error
  def prefetch_values(resolvers_and_requirements, address_hash) do
    with {:ok, fetched_values} <-
           resolvers_and_requirements
           |> Enum.flat_map(fn {_, reqs} -> Map.values(reqs) end)
           |> fetch_values(address_hash),
         resolvers_and_fetched_values when is_list(resolvers_and_fetched_values) <-
           Enum.reduce_while(resolvers_and_requirements, [], fn {resolver, reqs}, acc ->
             values = Enum.into(reqs, %{}, fn {name, req} -> {name, Map.get(fetched_values, req, :error)} end)

             if Enum.any?(values, &(elem(&1, 1) == :error)) do
               {:halt, :error}
             else
               {:cont, [{resolver, values} | acc]}
             end
           end) do
      {:ok, Enum.reverse(resolvers_and_fetched_values)}
    end
  end

  @doc """
  Fetches values for given eth_getStorageAt and eth_call requirements for a given address hash.

  ## Parameters
  - `reqs`: The list of eth_getStorageAt and eth_call requirements to fetch the values for.
  - `address_hash`: The address hash to fetch the values for.

  ## Returns
  - `{:ok, prefetched_values()}` if all of the values are fetched successfully,
    map can contain nil values for failed/reverted eth_call requests.
  - `:error` if the prefetching failed.
  """
  @spec fetch_values([ResolverBehaviour.fetch_requirement()], Hash.Address.t()) ::
          {:ok, %{ResolverBehaviour.fetch_requirement() => String.t() | nil}} | :error
  def fetch_values(reqs, address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    id_to_params = id_to_params(reqs)

    with {:ok, responses} <-
           id_to_params
           |> Enum.map(fn {index, req} -> encode_request(req, address_hash, index) end)
           |> json_rpc(json_rpc_named_arguments),
         fetched_values when is_map(fetched_values) <-
           Enum.reduce_while(responses, %{}, fn result, acc ->
             with %{id: id} <- result,
                  {:ok, req} = Map.fetch(id_to_params, id),
                  {:ok, value} <- handle_response(req, result) do
               {:cont, Map.put(acc, req, value)}
             else
               _ ->
                 {:halt, :error}
             end
           end) do
      {:ok, fetched_values}
    else
      _ -> :error
    end
  end

  @doc """
  Fetches value for the given eth_getStorageAt or eth_call request for a given address hash.

  The eth_call request is allowed to fail/revert, nil will be returned in such case.

  ## Parameters
  - `req`: The eth_getStorageAt or eth_call request to fetch the value for.
  - `address_hash`: The address hash to fetch the value for.

  ## Returns
  - `{:ok, String.t() | nil}` if the value is fetched successfully.
  - `:error` if the fetch request failed.
  """
  @spec fetch_value(ResolverBehaviour.fetch_requirement(), Hash.Address.t()) :: {:ok, String.t() | nil} | :error
  def fetch_value(req, address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    case req |> encode_request(address_hash, 0) |> json_rpc(json_rpc_named_arguments) do
      {:ok, response} -> handle_response(req, %{result: response})
      {:error, error} -> handle_response(req, %{error: error})
    end
  end

  defp encode_request({:storage, value}, address_hash, index),
    do: Contract.eth_get_storage_at_request(to_string(address_hash), value, index)

  defp encode_request({:call, value}, address_hash, index),
    do: Contract.eth_call_request(value, to_string(address_hash), index, nil, nil)

  defp handle_response({:storage, _}, %{result: result}) when is_binary(result), do: {:ok, result}
  defp handle_response({:call, _}, %{result: result}) when is_binary(result), do: {:ok, result}
  # TODO: it'll be better to return nil only for the revert-related errors
  defp handle_response({:call, _}, %{error: _}), do: {:ok, nil}
  defp handle_response(_, _), do: :error

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
         {:ok, %Data{bytes: bytes}} <- Data.cast(value),
         false <- byte_size(bytes) > 32 do
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
    implementations_info = prepare_implementations(proxy_implementation.addresses)
    implementation_addresses = proxy_implementation.address_hashes
    implementation_names = proxy_implementation.names

    implementation_addresses
    |> Enum.zip(implementation_names)
    |> Enum.map(fn {address_hash, name} ->
      %{
        "address_hash" => Address.checksum(address_hash),
        "name" => name
      }
      |> chain_type_fields(implementations_info)
    end)
  end

  if @chain_type == :filecoin do
    def chain_type_fields(%{"address_hash" => address_hash} = address, implementations_info) do
      Map.put(address, "filecoin_robust_address", implementations_info[address_hash])
    end

    def prepare_implementations(addresses) when is_list(addresses) do
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

  @doc """
  Returns conflicting implementations info for a given proxy implementation.

  ## Parameters

    * `proxy_implementation` - An `Implementation.t()` struct.

  ## Returns

  A list of maps containing information about the conflicting proxy implementations, if more than 1 proxy type is present.

  """
  @spec conflicting_implementations_info(Implementation.t() | nil) :: [map()] | nil
  def conflicting_implementations_info(
        %{
          proxy_type: proxy_type,
          conflicting_proxy_types: conflicting_proxy_types,
          conflicting_address_hashes: conflicting_address_hashes
        } = proxy_implementation
      )
      when not is_nil(proxy_type) and is_list(conflicting_proxy_types) and is_list(conflicting_address_hashes) do
    implementations_info = prepare_implementations(proxy_implementation.conflicting_addresses)

    conflicting_implementations =
      conflicting_proxy_types
      |> Enum.zip(conflicting_address_hashes)
      |> Enum.map(fn {proxy_type, address_hashes} ->
        %{
          "proxy_type" => proxy_type,
          "implementations" =>
            Enum.map(
              address_hashes,
              &(%{"address_hash" => Address.checksum(&1)} |> chain_type_fields(implementations_info))
            )
        }
      end)

    [
      %{
        "proxy_type" => proxy_type,
        "implementations" => proxy_object_info(proxy_implementation)
      }
      | conflicting_implementations
    ]
  end

  def conflicting_implementations_info(_proxy_implementation), do: nil
end
