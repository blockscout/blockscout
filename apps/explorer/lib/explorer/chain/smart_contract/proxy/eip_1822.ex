defmodule Explorer.Chain.SmartContract.Proxy.EIP1822 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1822 Universal Upgradeable Proxy Standard (UUPS)
  """
  alias Explorer.Chain.{Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy

  @burn_address_hash_string_32 "0x0000000000000000000000000000000000000000000000000000000000000000"

  defguard is_burn_signature(term) when term in ["0x", "0x0", @burn_address_hash_string_32]
  defguard is_burn_signature_or_nil(term) when is_burn_signature(term) or term == nil

  # keccak256("PROXIABLE")
  @storage_slot_proxiable "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7"

  @doc """
  Get implementation address following EIP-1967
  """
  @spec get_implementation_address(Hash.Address.t()) :: SmartContract.t() | nil
  def get_implementation_address(proxy_address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    proxiable_contract_address_hash_string =
      Proxy.get_implementation_from_storage(
        proxy_address_hash,
        @storage_slot_proxiable,
        json_rpc_named_arguments
      )

    Proxy.abi_decode_address_output(proxiable_contract_address_hash_string)
  end
end
