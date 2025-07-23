defmodule Explorer.Chain.SmartContract.Proxy.BasicImplementationGetter do
  @moduledoc """
  Module for fetching proxy implementation from public smart-contract method
  """

  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

  @behaviour ResolverBehaviour

  # 0x5c60da1b = keccak256(implementation())
  @implementation_signature <<0x5C60DA1B::4-unit(8)>>
  # 0xaaf10f42 = keccak256(getImplementation())
  @get_implementation_signature <<0xAAF10F42::4-unit(8)>>
  # 0xbb82aa5e = keccak256(comptrollerImplementation())
  @comptroller_implementation_signature <<0xBB82AA5E::4-unit(8)>>

  def quick_resolve_implementations(address, proxy_type) do
    signature =
      case proxy_type do
        :basic_implementation -> @implementation_signature
        :basic_get_implementation -> @get_implementation_signature
        :comptroller -> @comptroller_implementation_signature
        _ -> nil
      end

    # don't resolve implementations if the bytecode doesn't contain function selector in it
    if signature && address.contract_code && :binary.match(address.contract_code.bytes, signature) != :nomatch do
      {:cont,
       %{
         implementation_getter: {:call, "0x" <> Base.encode16(signature, case: :lower)}
       }}
    else
      nil
    end
  end

  def resolve_implementations(_proxy_address, _proxy_type, prefetched_values) do
    with {:ok, value} <- Map.fetch(prefetched_values, :implementation_getter),
         {:ok, address_hash} <- Proxy.extract_address_hash(value) do
      {:ok, [address_hash]}
    else
      :error -> :error
      _ -> nil
    end
  end
end
