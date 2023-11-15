defmodule Explorer.Chain.SmartContract.Proxy.Basic do
  @moduledoc """
  Module for fetching proxy implementation from specific smart-contract getter
  """

  alias Explorer.Chain.SmartContract
  alias Explorer.SmartContract.Reader

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
               "#{signature}" => []
             },
             false
           ) do
        %{^signature => {:ok, [result]}} -> result
        _ -> nil
      end

    adds_0x_to_address(implementation_address)
  end

  @doc """
  Adds 0x to address at the beginning
  """
  @spec adds_0x_to_address(nil | binary()) :: nil | binary()
  def adds_0x_to_address(nil), do: nil

  def adds_0x_to_address(address) do
    if address do
      if String.starts_with?(address, "0x") do
        address
      else
        "0x" <> Base.encode16(address, case: :lower)
      end
    end
  end
end
