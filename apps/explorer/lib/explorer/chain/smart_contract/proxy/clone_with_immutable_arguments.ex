defmodule Explorer.Chain.SmartContract.Proxy.CloneWithImmutableArguments do
  @moduledoc """
  Module for fetching proxy implementation from clone contracts with immutable arguments.
  Supports both wighawag (https://github.com/wighawag/clones-with-immutable-args) and
  solady (https://github.com/Vectorized/solady/blob/main/src/utils/LibClone.sol) variants.
  """

  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

  @behaviour ResolverBehaviour

  @impl true
  def quick_resolve_implementations(proxy_address, _proxy_type) do
    case proxy_address.contract_code && proxy_address.contract_code.bytes do
      # wighawag variant: https://github.com/wighawag/clones-with-immutable-args/blob/196f1ecc6485c1bf2d41677fa01d3df4927ff9ce/src/ClonesWithImmutableArgs.sol
      <<0x3D3D3D3D363D3D3761::9-unit(8), _::2-bytes, 0x603736393661::6-unit(8), _::2-bytes, 0x013D73::3-unit(8),
        template_address::20-bytes, _::binary>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        {:ok, [template_address_hash]}

      # solady variant: https://github.com/Vectorized/solady/blob/main/src/utils/LibClone.sol#L620
      <<0x363D3D373D3D3D363D73::10-unit(8), template_address::20-bytes, 0x5AF43D3D93803E602A57FD5BF3::13-unit(8),
        _::binary>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        {:ok, [template_address_hash]}

      _ ->
        nil
    end
  end
end
