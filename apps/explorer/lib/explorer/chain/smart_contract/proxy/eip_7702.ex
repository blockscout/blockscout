defmodule Explorer.Chain.SmartContract.Proxy.EIP7702 do
  @moduledoc """
  Module for fetching EOA delegate from https://eips.ethereum.org/EIPS/eip-7702
  """

  alias Explorer.Chain.{Address, Hash}

  @doc """
  Get implementation address hash following EIP-7702.
  """
  @spec match_bytecode_and_resolve_implementation(Address.t()) :: Hash.Address.t() | nil
  def match_bytecode_and_resolve_implementation(proxy_address) do
    case proxy_address.contract_code && proxy_address.contract_code.bytes do
      <<0xEF0100::3-unit(8), template_address::20-bytes>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        template_address_hash

      _ ->
        nil
    end
  end
end
