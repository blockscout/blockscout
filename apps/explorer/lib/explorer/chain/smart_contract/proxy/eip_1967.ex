defmodule Explorer.Chain.SmartContract.Proxy.EIP1967 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1967 (Proxy Storage Slots)
  """
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.SmartContract.Proxy

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

  @spec get_prefetch_requirements(Address.t(), :eip1967 | :eip1967_oz | :eip1967_beacon) ::
          [Proxy.prefetch_requirement()]
  def get_prefetch_requirements(_, :eip1967), do: [storage: @storage_slot_logic_contract_address]
  def get_prefetch_requirements(_, :eip1967_oz), do: [storage: @storage_slot_openzeppelin_contract_address]
  def get_prefetch_requirements(_, :eip1967_beacon), do: [storage: @storage_slot_beacon_contract_address]

  @doc """
  Get implementation address hash following EIP-1967.
  """
  @spec resolve_implementations(Address.t(), :eip1967 | :eip1967_oz | :eip1967_beacon, Proxy.prefetched_values() | nil) ::
          [Hash.Address.t()] | :error | nil
  def resolve_implementations(proxy_address, proxy_type, prefetched_values \\ nil) do
    req = proxy_address |> get_prefetch_requirements(proxy_type) |> Enum.at(0)

    with {:ok, value} <- Proxy.fetch_value(req, proxy_address.hash, prefetched_values),
         {:ok, stored_address_hash} <- Proxy.extract_address_hash(value) do
      if proxy_type == :eip1967_beacon do
        with {:ok, value} <- Proxy.fetch_value({:call, @implementation_signature}, stored_address_hash),
             {:ok, implementation_address_hash} <- Proxy.extract_address_hash(value) do
          [implementation_address_hash]
        end
      else
        [stored_address_hash]
      end
    else
      :error -> :error
      _ -> nil
    end
  end
end
