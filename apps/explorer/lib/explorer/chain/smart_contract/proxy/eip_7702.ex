defmodule Explorer.Chain.SmartContract.Proxy.EIP7702 do
  @moduledoc """
  Module for fetching EOA delegate from https://eips.ethereum.org/EIPS/eip-7702
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy

  @doc """
  Get delegate address following EIP-7702
  """
  @spec get_implementation_smart_contract(Hash.Address.t(), Keyword.t()) :: SmartContract.t() | nil
  def get_implementation_smart_contract(address_hash, options \\ []) do
    address_hash
    |> get_implementation_address_hash_string(options)
    |> Proxy.implementation_to_smart_contract(options)
  end

  @doc """
  Get delegate address hash string following EIP-7702
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

            contract_bytecode |> get_delegate_address() |> Proxy.abi_decode_address_output()

          _ ->
            nil
        end
    end
  end

  defp get_delegate_address(contract_bytecode) do
    case contract_bytecode do
      "ef0100" <> <<template_address::binary-size(40)>> ->
        "0x" <> template_address

      _ ->
        nil
    end
  end
end
