defmodule Explorer.Chain.SmartContract.Proxy.EIP930 do
  @moduledoc """
  Module for fetching proxy implementation from smart-contract getter following https://github.com/ethereum/EIPs/issues/930
  """

  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.Proxy.Basic
  alias Explorer.SmartContract.Reader

  @storage_slot_logic_contract_address "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

  @doc """
  Gets implementation hash string of proxy contract from getter.
  """
  @spec get_implementation_address_hash_string(binary, binary, SmartContract.abi()) :: nil | binary
  def get_implementation_address_hash_string(signature, proxy_address_hash, abi) do
    implementation_address =
      case Reader.query_contract(
             proxy_address_hash,
             abi,
             %{
               "#{signature}" => [@storage_slot_logic_contract_address]
             },
             false
           ) do
        %{^signature => {:ok, [result]}} -> result
        _ -> nil
      end

    Basic.adds_0x_to_address(implementation_address)
  end
end
