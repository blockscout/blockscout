defmodule Explorer.Chain.SmartContract.Proxy.EIP1822 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1822 Universal Upgradeable Proxy Standard (UUPS)
  """
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.SmartContract.Proxy

  # keccak256("PROXIABLE")
  @storage_slot_proxiable "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7"

  @spec get_prefetch_requirements(Address.t(), atom()) :: [Proxy.prefetch_requirement()]
  def get_prefetch_requirements(_, _), do: [storage: @storage_slot_proxiable]

  @doc """
  Get implementation address hash following EIP-1822.
  """
  @spec resolve_implementations(Address.t(), atom(), Proxy.prefetched_values()) :: [Hash.Address.t()] | :error | nil
  def resolve_implementations(proxy_address, proxy_type, prefetched_values) do
    req = proxy_address |> get_prefetch_requirements(proxy_type) |> Enum.at(0)

    with {:ok, value} <- Proxy.fetch_value(req, proxy_address.hash, prefetched_values),
         {:ok, address_hash} <- Proxy.extract_address_hash(value) do
      [address_hash]
    else
      :error -> :error
      _ -> nil
    end
  end
end
