defmodule Explorer.Chain.SmartContract.Proxy.EIP7702 do
  @moduledoc """
  Module for fetching EOA delegate from https://eips.ethereum.org/EIPS/eip-7702
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.SmartContract.Proxy

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
            contract_code_bytes |> get_delegate_address() |> Proxy.abi_decode_address_output()

          _ ->
            nil
        end
    end
  end

  @doc """
  Extracts the EIP-7702 delegate address from the bytecode
  """
  @spec get_delegate_address(binary()) :: String.t() | nil
  def get_delegate_address(contract_code_bytes) do
    case contract_code_bytes do
      # 0xef0100 <> address
      <<239, 1, 0>> <> <<address::binary-size(20)>> -> "0x" <> Base.encode16(address, case: :lower)
      _ -> nil
    end
  end
end
