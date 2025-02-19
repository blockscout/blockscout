defmodule Explorer.Chain.SmartContract.Proxy.MasterCopy do
  @moduledoc """
  Module for fetching master-copy proxy implementation
  """

  alias EthereumJSONRPC.Contract
  alias Explorer.Chain.Hash
  alias Explorer.Chain.SmartContract.Proxy

  import Explorer.Chain.SmartContract.Proxy.Models.Implementation, only: [is_burn_signature: 1]

  @doc """
  Gets implementation address hash string for proxy contract from master-copy pattern
  """
  @spec get_implementation_address_hash_string(Hash.Address.t()) :: binary() | nil
  def get_implementation_address_hash_string(proxy_address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    master_copy_storage_pointer = "0x0"

    implementation_address =
      case Contract.eth_get_storage_at_request(
             proxy_address_hash,
             master_copy_storage_pointer,
             nil,
             json_rpc_named_arguments
           ) do
        {:ok, empty_address}
        when is_burn_signature(empty_address) ->
          "0x"

        {:ok, "0x" <> storage_value} ->
          logic_contract_address = Proxy.extract_address_hex_from_storage_pointer(storage_value)
          logic_contract_address

        _ ->
          nil
      end

    Proxy.abi_decode_address_output(implementation_address)
  end

  @doc """
  Checks if the input of the smart-contract follows master-copy (or Safe) proxy pattern before
  fetching its implementation from 0x0 storage pointer
  """
  @spec pattern?(map()) :: any()
  def pattern?(method) do
    Map.get(method, "type") == "constructor" &&
      method
      |> Enum.find(fn item ->
        case item do
          {"inputs", inputs} ->
            find_input_by_name(inputs, "_masterCopy") || find_input_by_name(inputs, "_singleton")

          _ ->
            false
        end
      end)
  end

  defp find_input_by_name(inputs, name) do
    inputs
    |> Enum.find(fn input ->
      Map.get(input, "name") == name
    end)
  end
end
