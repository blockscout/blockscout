defmodule Explorer.Chain.SmartContract.Proxy.EIP930 do
  @moduledoc """
  Module for fetching proxy implementation from smart-contract getter following https://github.com/ethereum/EIPs/issues/930
  """

  alias Explorer.Chain.SmartContract
  alias Explorer.Chain.SmartContract.Proxy.EIP1967
  alias Explorer.Helper, as: ExplorerHelper
  alias Explorer.SmartContract.Reader

  @doc """
  Gets implementation hash string of proxy contract from getter.
  """
  @spec get_implementation_address_hash_string(binary(), binary(), SmartContract.abi()) :: nil | binary()
  def get_implementation_address_hash_string(signature, proxy_address_hash, abi) do
    implementation_address =
      case Reader.query_contract(
             proxy_address_hash,
             abi,
             %{
               "#{signature}" => [EIP1967.storage_slot_logic_contract_address()]
             },
             false
           ) do
        %{^signature => {:ok, [result]}} -> result
        _ -> nil
      end

    ExplorerHelper.adds_0x_prefix(implementation_address)
  end
end
