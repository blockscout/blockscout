defmodule Explorer.Chain.SmartContract.Proxy.CloneWithImmutableArguments do
  @moduledoc """
  Module for fetching proxy implementation from https://github.com/wighawag/clones-with-immutable-args
  """

  alias Explorer.Chain.{Address, Hash}

  @doc """
  Get implementation address hash following "Clone with immutable arguments" proxy pattern.
  """
  @spec match_bytecode_and_resolve_implementation(Address.t()) :: Hash.Address.t() | nil
  def match_bytecode_and_resolve_implementation(proxy_address) do
    case proxy_address.contract_code && proxy_address.contract_code.bytes do
      <<0x3D3D3D3D363D3D3761::9-unit(8), _::2-bytes, 0x603736393661::6-unit(8), _::2-bytes, 0x013D73::3-unit(8),
        template_address::20-bytes, _::binary>> ->
        {:ok, template_address_hash} = Hash.Address.cast(template_address)
        template_address_hash

      _ ->
        nil
    end
  end
end
