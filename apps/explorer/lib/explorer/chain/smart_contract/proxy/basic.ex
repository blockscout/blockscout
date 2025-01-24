defmodule Explorer.Chain.SmartContract.Proxy.Basic do
  @moduledoc """
  Module for fetching proxy implementation from specific smart-contract getter
  """

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Helper, as: SmartContractHelper

  @doc """
  Gets implementation hash string of proxy contract from getter.
  """
  @spec get_implementation_address_hash_string(binary(), binary(), SmartContract.abi()) :: binary() | nil | :error
  def get_implementation_address_hash_string(signature, proxy_address_hash_string, abi) do
    SmartContractHelper.get_binary_string_from_contract_getter(signature, proxy_address_hash_string, abi)
  end
end
