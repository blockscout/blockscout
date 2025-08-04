defmodule Explorer.Chain.SmartContract.Proxy.EIP1967 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1967 (Proxy Storage Slots)
  """
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

  @behaviour ResolverBehaviour

  # 0x5c60da1b = keccak256(implementation())
  @implementation_signature "0x5c60da1b"

  # obtained as bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
  @storage_slot_logic_contract_address "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
  # obtained as bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)
  @storage_slot_beacon_contract_address "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50"

  # to be precise, it is not the part of the EIP-1967 standard, but still uses the same pattern
  # changes requested by https://github.com/blockscout/blockscout/issues/5292
  # This is the keccak-256 hash of "org.zeppelinos.proxy.implementation"
  @storage_slot_openzeppelin_contract_address "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3"

  def quick_resolve_implementations(_proxy_address, proxy_type) do
    storage_slot =
      case proxy_type do
        :eip1967 -> @storage_slot_logic_contract_address
        :eip1967_oz -> @storage_slot_openzeppelin_contract_address
        :eip1967_beacon -> @storage_slot_beacon_contract_address
        _ -> nil
      end

    if is_nil(storage_slot) do
      nil
    else
      {:cont,
       %{
         implementation_slot: {:storage, storage_slot}
       }}
    end
  end

  def resolve_implementations(_proxy_address, proxy_type, prefetched_values) do
    with {:ok, value} <- Map.fetch(prefetched_values, :implementation_slot),
         {:ok, stored_address_hash} <- Proxy.extract_address_hash(value) do
      if proxy_type == :eip1967_beacon do
        with {:ok, value} <- Proxy.fetch_value({:call, @implementation_signature}, stored_address_hash),
             {:ok, implementation_address_hash} <- Proxy.extract_address_hash(value) do
          {:ok, [implementation_address_hash]}
        end
      else
        {:ok, [stored_address_hash]}
      end
    else
      :error -> :error
      _ -> nil
    end
  end
end
