defmodule Explorer.Chain.SmartContract.Proxy.EIP1167 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1167 (Minimal Proxy Contract)
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy

  @doc """
  Get implementation address following EIP-1167
  """
  @spec get_implementation_address(Hash.Address.t(), Keyword.t()) :: SmartContract.t() | nil
  def get_implementation_address(address_hash, options \\ []) do
    address_hash
    |> get_implementation_address_hash_string(options)
    |> implementation_to_smart_contract(options)
  end

  @doc """
  Get implementation address hash string following EIP-1167
  """
  @spec get_implementation_address_hash_string(Hash.Address.t(), Keyword.t()) :: String.t() | nil
  def get_implementation_address_hash_string(address_hash, options \\ []) do
    case Chain.select_repo(options).get(Address, address_hash) do
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
      "363d3d373d3d3d363d73" <> <<template_address::binary-size(40)>> <> _ ->
        "0x" <> template_address

      _ ->
        nil
    end
  end

  defp implementation_to_smart_contract(nil, _options), do: nil

  defp implementation_to_smart_contract(address_hash, options) do
    address_hash
    |> SmartContract.get_smart_contract_query()
    |> Chain.select_repo(options).one(timeout: 10_000)
  end
end
