defmodule Explorer.Chain.SmartContract.Proxy.EIP1822 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1822 Universal Upgradeable Proxy Standard (UUPS)
  """

  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

  @behaviour ResolverBehaviour

  # keccak256("PROXIABLE")
  @storage_slot_proxiable "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7"

  def quick_resolve_implementations(_proxy_address, _proxy_type),
    do:
      {:cont,
       %{
         implementation_slot: {:storage, @storage_slot_proxiable}
       }}

  def resolve_implementations(_proxy_address, _proxy_type, prefetched_values) do
    with {:ok, value} <- Map.fetch(prefetched_values, :implementation_slot),
         {:ok, address_hash} <- Proxy.extract_address_hash(value) do
      {:ok, [address_hash]}
    else
      :error -> :error
      _ -> nil
    end
  end
end
