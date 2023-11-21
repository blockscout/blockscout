defmodule Explorer.Chain.SmartContract.Proxy.EIP1967 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1967 (Proxy Storage Slots)
  """
  alias EthereumJSONRPC.Contract
  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.Basic

  import Explorer.Chain.SmartContract, only: [is_burn_signature_or_nil: 1]

  # supported signatures:
  # 5c60da1b = keccak256(implementation())
  @implementation_signature "5c60da1b"

  @storage_slot_logic_contract_address "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

  # to be precise, it is not the part of the EIP-1967 standard, but still uses the same pattern
  # changes requested by https://github.com/blockscout/blockscout/issues/5292
  # This is the keccak-256 hash of "org.zeppelinos.proxy.implementation"
  @storage_slot_openzeppelin_contract_address "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3"

  @doc """
  Get implementation address hash string following EIP-1967
  """
  @spec get_implementation_address_hash_string(Hash.Address.t()) :: nil | binary
  def get_implementation_address_hash_string(proxy_address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    implementation_address_hash_string =
      Proxy.get_implementation_from_storage(
        proxy_address_hash,
        @storage_slot_logic_contract_address,
        json_rpc_named_arguments
      ) ||
        fetch_beacon_proxy_implementation(proxy_address_hash, json_rpc_named_arguments) ||
        Proxy.get_implementation_from_storage(
          proxy_address_hash,
          @storage_slot_openzeppelin_contract_address,
          json_rpc_named_arguments
        )

    Proxy.abi_decode_address_output(implementation_address_hash_string)
  end

  # changes requested by https://github.com/blockscout/blockscout/issues/4770
  # for support BeaconProxy pattern
  defp fetch_beacon_proxy_implementation(proxy_address_hash, json_rpc_named_arguments) do
    # https://eips.ethereum.org/EIPS/eip-1967
    storage_slot_beacon_contract_address = "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50"

    implementation_method_abi = [
      %{
        "type" => "function",
        "stateMutability" => "view",
        "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
        "name" => "implementation",
        "inputs" => []
      }
    ]

    case Contract.eth_get_storage_at_request(
           proxy_address_hash,
           storage_slot_beacon_contract_address,
           nil,
           json_rpc_named_arguments
         ) do
      {:ok, empty_address}
      when is_burn_signature_or_nil(empty_address) ->
        nil

      {:ok, beacon_contract_address} ->
        case beacon_contract_address
             |> Proxy.abi_decode_address_output()
             |> Basic.get_implementation_address_hash_string(
               @implementation_signature,
               implementation_method_abi
             ) do
          <<implementation_address::binary-size(42)>> ->
            implementation_address

          _ ->
            beacon_contract_address
        end

      _ ->
        nil
    end
  end
end
