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
    address_length = div(String.length(contract_bytecode), 2) - 25

    if address_length in 10..20 do
      push_n = String.downcase(Integer.to_string(95 + address_length, 16))
      start_pattern = "363d3d373d3d3d363d" <> push_n
      end_pattern = "5af43d82803e903d91602b57fd5bf3"

      if String.starts_with?(contract_bytecode, start_pattern) && String.ends_with?(contract_bytecode, end_pattern) do
        "0x" <>
          String.pad_leading(binary_part(contract_bytecode, byte_size(start_pattern), address_length * 2), 40, "0")
      else
        nil
      end
    else
      nil
    end
  end

  defp implementation_to_smart_contract(nil, _options), do: nil

  defp implementation_to_smart_contract(address_hash, options) do
    necessity_by_association = %{
      :smart_contract_additional_sources => :optional
    }

    address_hash
    |> SmartContract.get_smart_contract_query()
    |> Chain.join_associations(necessity_by_association)
    |> Chain.select_repo(options).one(timeout: 10_000)
  end
end
