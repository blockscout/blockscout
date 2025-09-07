defmodule Explorer.Chain.SmartContract.Proxy.EIP1167 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1167 (Minimal Proxy Contract)
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy

  @doc """
  Get implementation address hash string following EIP-1167. It returns the value as array of the strings.
  """
  @spec get_implementation_address_hash_strings(Hash.Address.t(), [Chain.api?()]) :: [binary()]
  def get_implementation_address_hash_strings(proxy_address_hash, options \\ []) do
    case get_implementation_address_hash_string(proxy_address_hash, options) do
      nil -> []
      implementation_address_hash_string -> [implementation_address_hash_string]
    end
  end

  # Get implementation address hash string following EIP-1167
  @spec get_implementation_address_hash_string(Hash.Address.t(), Keyword.t()) :: binary() | nil
  defp get_implementation_address_hash_string(proxy_address_hash, options) do
    case Chain.select_repo(options).get(Address, proxy_address_hash) do
      nil ->
        nil

      target_address ->
        contract_code = target_address.contract_code

        case contract_code do
          %Chain.Data{bytes: contract_code_bytes} ->
            contract_bytecode = Base.encode16(contract_code_bytes, case: :lower)

            contract_bytecode |> get_proxy_eip_1167() |> Proxy.abi_decode_address_output()

          _ ->
            nil
        end
    end
  end

  defp get_proxy_eip_1167(contract_bytecode) do
    case contract_bytecode do
      "363d3d373d3d3d363d73" <> <<template_address::binary-size(40)>> <> "5af43d82803e903d91602b57fd5bf3" ->
        "0x" <> template_address

      # https://medium.com/coinmonks/the-more-minimal-proxy-5756ae08ee48
      "3d3d3d3d363d3d37363d73" <> <<template_address::binary-size(40)>> <> "5af43d3d93803e602a57fd5bf3" ->
        "0x" <> template_address

      _ ->
        nil
    end
  end

  @doc """
  Get implementation address following EIP-1167. It is used in old UI.
  """
  @spec get_implementation_smart_contract(Hash.Address.t(), Keyword.t()) :: SmartContract.t() | nil
  def get_implementation_smart_contract(address_hash, options \\ []) do
    address_hash
    |> get_implementation_address_hash_string(options)
    |> Proxy.implementation_to_smart_contract(options)
  end
end
