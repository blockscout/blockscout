defmodule Explorer.Chain.SmartContract.Proxy.EIP1167 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1167 (Minimal Proxy Contract)
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy

  @doc """
  Get implementation address hash following EIP-1167.
  """
  @spec match_bytecode_and_resolve_implementation(Address.t()) :: Hash.Address.t() | nil
  def match_bytecode_and_resolve_implementation(proxy_address) do
    case proxy_address.contract_code && proxy_address.contract_code.bytes do
      <<0x363D3D373D3D3D363D73::10-unit(8), template_address::20-bytes, 0x5AF43D82803E903D91602B57FD5BF3::15-unit(8)>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        template_address_hash

      <<0x3D3D3D3D363D3D37363D73::11-unit(8), template_address::20-bytes, 0x5AF43D3D93803E602A57FD5BF3::13-unit(8)>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        template_address_hash

      _ ->
        nil
    end
  end

  @doc """
  Get implementation address following EIP-1167. It is used in old UI.
  """
  @spec get_implementation_smart_contract(Hash.Address.t(), Keyword.t()) :: SmartContract.t() | nil
  def get_implementation_smart_contract(address_hash, options \\ []) do
    address = Chain.select_repo(options).get(Address, address_hash)

    address
    |> match_bytecode_and_resolve_implementation()
    |> Proxy.implementation_to_smart_contract(options)
  end
end
