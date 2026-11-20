# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.SmartContract.Proxy.EIP1167 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1167 (Minimal Proxy Contract)
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

  @behaviour ResolverBehaviour

  @impl true
  def quick_resolve_implementations(proxy_address, _proxy_type) do
    case proxy_address.contract_code && proxy_address.contract_code.bytes do
      <<0x363D3D373D3D3D363D73::10-unit(8), template_address::20-bytes, 0x5AF43D82803E903D91602B57FD5BF3::15-unit(8)>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        {:ok, [template_address_hash]}

      <<0x3D3D3D3D363D3D37363D73::11-unit(8), template_address::20-bytes, 0x5AF43D3D93803E602A57FD5BF3::13-unit(8)>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        {:ok, [template_address_hash]}

      # 0xSplits modified minimal proxy: the forwarder above (with adjusted jump destination) behind a `receive()`
      # stub that emits `ReceiveETH(uint256)` and skips `DELEGATECALL` when there is no calldata.
      # The whole 89-byte runtime code is matched, so nothing but the template address can vary.
      # https://github.com/0xSplits/splits-utils/blob/1ad561279084964e94a2f3d3cf75f490d2318ccf/src/LibClone.sol
      <<0x36602C57343D527F::8-unit(8), 0x9E4AC34F21C619CEFC926C8BD93B54BF5A39C7AB2127A895AF1CC0691D7E3DFF::32-unit(8),
        0x593DA1005B3D3D3D3D363D3D37363D73::16-unit(8), template_address::20-bytes,
        0x5AF43D3D93803E605757FD5BF3::13-unit(8)>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        {:ok, [template_address_hash]}

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

    case address && quick_resolve_implementations(address, :eip1167) do
      {:ok, [address_hash]} -> Proxy.implementation_to_smart_contract(address_hash, options)
      _ -> nil
    end
  end
end
