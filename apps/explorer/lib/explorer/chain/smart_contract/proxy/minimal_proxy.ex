# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.SmartContract.Proxy.MinimalProxy do
  @moduledoc """
  Module for fetching proxy implementation from minimal proxy contracts where the EIP-1167-like
  bytecode sequence is embedded somewhere in the middle of the contract bytecode rather than at
  the start.

  The pattern `3D3D3D3D363D3D37363D73` is located anywhere in the bytecode, and the 20 bytes
  immediately following it are the implementation address.
  """

  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

  @behaviour ResolverBehaviour

  @pattern <<0x3D3D3D3D363D3D37363D73::11-unit(8)>>

  @impl true
  def quick_resolve_implementations(proxy_address, _proxy_type) do
    case proxy_address.contract_code && proxy_address.contract_code.bytes do
      bytes when is_binary(bytes) ->
        case :binary.match(bytes, @pattern) do
          {pos, len} when byte_size(bytes) >= pos + len + 20 ->
            template_address = binary_part(bytes, pos + len, 20)
            {:ok, template_address_hash} = Hash.Address.cast(template_address)
            {:ok, [template_address_hash]}

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
