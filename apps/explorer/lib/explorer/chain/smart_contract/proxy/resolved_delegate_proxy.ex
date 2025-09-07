defmodule Explorer.Chain.SmartContract.Proxy.ResolvedDelegateProxy do
  @moduledoc """
  Module for fetching proxy implementation from ResolvedDelegateProxy https://github.com/ethereum-optimism/optimism/blob/9580179013a04b15e6213ae8aa8d43c3f559ed9a/packages/contracts-bedrock/src/legacy/ResolvedDelegateProxy.sol
  """
  alias Explorer.Chain
  alias Explorer.Chain.{Hash, SmartContract}
  alias Explorer.SmartContract.Helper, as: SmartContractHelper

  # 8da5cb5b = keccak256(owner())
  @owner_signature "8da5cb5b"

  # 204e1c7a = keccak256(getProxyImplementation(address))
  @get_proxy_implementation_signature "204e1c7a"

  @resolved_delegate_proxy_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "contract AddressManager",
          "name" => "_addressManager",
          "type" => "address"
        },
        %{
          "internalType" => "string",
          "name" => "_implementationName",
          "type" => "string"
        }
      ],
      "stateMutability" => "nonpayable",
      "type" => "constructor"
    },
    %{"stateMutability" => "payable", "type" => "fallback"}
  ]

  @owner_method_abi [
    %{
      "inputs" => [],
      "name" => "owner",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @get_proxy_implementation_method_abi [
    %{
      "inputs" => [
        %{
          "internalType" => "address",
          "name" => "_proxy",
          "type" => "address"
        }
      ],
      "name" => "getProxyImplementation",
      "outputs" => [
        %{
          "internalType" => "address",
          "name" => "",
          "type" => "address"
        }
      ],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @doc """
  Get implementation address hash string following ResolvedDelegateProxy proxy pattern. It returns the value as array of the strings.
  """
  @spec get_implementation_address_hash_strings(Hash.Address.t(), [Chain.api?()]) :: [binary()] | :error
  def get_implementation_address_hash_strings(proxy_address_hash, options \\ []) do
    case get_implementation_address_hash_string(proxy_address_hash, options) do
      nil -> []
      :error -> :error
      implementation_address_hash_string -> [implementation_address_hash_string]
    end
  end

  @doc """
  Returns the ABI of the ResolvedDelegateProxy smart contract.
  """
  @spec resolved_delegate_proxy_abi() :: [map()]
  def resolved_delegate_proxy_abi do
    @resolved_delegate_proxy_abi
  end

  # Get implementation address hash string following ResolvedDelegateProxy proxy pattern
  @spec get_implementation_address_hash_string(Hash.Address.t(), Keyword.t()) :: binary() | nil | :error
  defp get_implementation_address_hash_string(proxy_address_hash, options) do
    proxy_smart_contract =
      proxy_address_hash
      |> SmartContract.address_hash_to_smart_contract(options)

    if proxy_smart_contract && proxy_smart_contract.abi == @resolved_delegate_proxy_abi do
      case SmartContract.format_constructor_arguments(
             proxy_smart_contract.abi,
             proxy_smart_contract.constructor_arguments
           ) do
        [[address_manager_hash_string, _address_manager_type_abi], _] ->
          owner_address_hash_string = get_owner_from_address_manager(address_manager_hash_string)

          get_implementation_from_owner(owner_address_hash_string, proxy_address_hash)

        _ ->
          :error
      end
    else
      nil
    end
  end

  defp get_owner_from_address_manager(address_manager_hash_string) do
    case @owner_signature
         |> SmartContractHelper.get_binary_string_from_contract_getter(
           address_manager_hash_string,
           @owner_method_abi
         ) do
      <<owner_address_hash_string::binary-size(42)>> ->
        owner_address_hash_string

      _other_result ->
        nil
    end
  end

  defp get_implementation_from_owner(nil, _proxy_address_hash), do: nil

  defp get_implementation_from_owner(owner_address_hash_string, proxy_address_hash) do
    case @get_proxy_implementation_signature
         |> SmartContractHelper.get_binary_string_from_contract_getter(
           owner_address_hash_string,
           @get_proxy_implementation_method_abi,
           [to_string(proxy_address_hash)]
         ) do
      <<implementation_address_hash_string::binary-size(42)>> ->
        implementation_address_hash_string

      _other_result ->
        :error
    end
  end
end
