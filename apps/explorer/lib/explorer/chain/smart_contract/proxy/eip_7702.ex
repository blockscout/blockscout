defmodule Explorer.Chain.SmartContract.Proxy.EIP7702 do
  @moduledoc """
  Module for fetching EOA delegate from https://eips.ethereum.org/EIPS/eip-7702
  """

  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

  @behaviour ResolverBehaviour

  def quick_resolve_implementations(proxy_address, _proxy_type \\ :eip7702) do
    case proxy_address.contract_code && proxy_address.contract_code.bytes do
      <<0xEF0100::3-unit(8), template_address::20-bytes>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        {:ok, [template_address_hash]}

      _ ->
        nil
    end
  end
end
