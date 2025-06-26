defmodule Explorer.Chain.SmartContract.Proxy.EIP2535 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-2535 (Diamond Proxy)
  """

  # 52ef6b2c = keccak256(facetAddresses())
  @facet_addresses_signature "52ef6b2c"

  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Explorer.SmartContract.Helper, as: SmartContractHelper

  @facet_addresses_method_abi [
    %{
      "inputs" => [],
      "name" => "facetAddresses",
      "outputs" => [%{"internalType" => "address[]", "name" => "facetAddresses_", "type" => "address[]"}],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @spec get_implementation_address_hash_strings(Hash.Address.t(), [Chain.api?()]) :: [binary()]
  def get_implementation_address_hash_strings(proxy_address_hash, _options \\ []) do
    case @facet_addresses_signature
         |> SmartContractHelper.get_binary_string_from_contract_getter(
           to_string(proxy_address_hash),
           @facet_addresses_method_abi
         ) do
      implementation_addresses when is_list(implementation_addresses) ->
        implementation_addresses

      _ ->
        []
    end
  end
end
