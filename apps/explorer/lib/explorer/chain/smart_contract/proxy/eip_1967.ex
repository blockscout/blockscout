defmodule Explorer.Chain.SmartContract.Proxy.EIP1967 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-1967 (Proxy Storage Slots)
  """
  alias Explorer.Chain
  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.SmartContract.Helper, as: SmartContractHelper

  # supported signatures:
  # 5c60da1b = keccak256(implementation())
  @implementation_signature "5c60da1b"

  # obtained as bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
  @storage_slot_logic_contract_address "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
  # obtained as bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)
  @storage_slot_beacon_contract_address "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50"

  # to be precise, it is not the part of the EIP-1967 standard, but still uses the same pattern
  # changes requested by https://github.com/blockscout/blockscout/issues/5292
  # This is the keccak-256 hash of "org.zeppelinos.proxy.implementation"
  @storage_slot_openzeppelin_contract_address "0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3"

  @implementation_method_abi [
    %{
      "type" => "function",
      "stateMutability" => "view",
      "outputs" => [%{"type" => "address", "name" => "", "internalType" => "address"}],
      "name" => "implementation",
      "inputs" => []
    }
  ]

  @doc """
  Get implementation address hash string following EIP-1967. It returns the value as array of the strings.
  """
  @spec get_implementation_address_hash_strings(Hash.Address.t(), [Chain.api?()]) :: [binary()] | :error
  def get_implementation_address_hash_strings(proxy_address_hash, _options \\ []) do
    case get_implementation_address_hash_string(proxy_address_hash) do
      nil -> []
      :error -> :error
      implementation_address_hash_string -> [implementation_address_hash_string]
    end
  end

  # Get implementation address hash string following EIP-1967
  @spec get_implementation_address_hash_string(Hash.Address.t()) :: binary() | nil | :error
  defp get_implementation_address_hash_string(proxy_address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    implementation_address_hash_string_from_logic_storage_slot =
      Proxy.get_implementation_from_storage(
        proxy_address_hash,
        @storage_slot_logic_contract_address,
        json_rpc_named_arguments
      )

    implementation_address_hash_string =
      if implementation_address_hash_string_from_logic_storage_slot &&
           implementation_address_hash_string_from_logic_storage_slot !== :error do
        implementation_address_hash_string_from_logic_storage_slot
      else
        implementation_address_hash_string_from_beacon_storage_slot =
          fetch_beacon_proxy_implementation(proxy_address_hash, json_rpc_named_arguments)

        if implementation_address_hash_string_from_beacon_storage_slot &&
             implementation_address_hash_string_from_beacon_storage_slot !== :error do
          implementation_address_hash_string_from_beacon_storage_slot
        else
          Proxy.get_implementation_from_storage(
            proxy_address_hash,
            @storage_slot_openzeppelin_contract_address,
            json_rpc_named_arguments
          )
        end
      end

    Proxy.abi_decode_address_output(implementation_address_hash_string)
  end

  # changes requested by https://github.com/blockscout/blockscout/issues/4770
  # for support BeaconProxy pattern
  defp fetch_beacon_proxy_implementation(proxy_address_hash, json_rpc_named_arguments) do
    eip1967_beacon_address_hash_string =
      Proxy.get_implementation_from_storage(
        proxy_address_hash,
        @storage_slot_beacon_contract_address,
        json_rpc_named_arguments
      )

    case eip1967_beacon_address_hash_string do
      :error ->
        :error

      nil ->
        nil

      _ ->
        case @implementation_signature
             |> SmartContractHelper.get_binary_string_from_contract_getter(
               eip1967_beacon_address_hash_string,
               @implementation_method_abi
             ) do
          <<implementation_address_hash_string::binary-size(42)>> ->
            implementation_address_hash_string

          _ ->
            nil
        end
    end
  end

  @doc """
  Shares logic storage slot to other modules
  """
  @spec storage_slot_logic_contract_address() :: String.t()
  def storage_slot_logic_contract_address do
    @storage_slot_logic_contract_address
  end
end
