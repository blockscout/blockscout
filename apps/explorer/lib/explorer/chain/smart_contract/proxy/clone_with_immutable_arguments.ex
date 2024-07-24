defmodule Explorer.Chain.SmartContract.Proxy.CloneWithImmutableArguments do
  @moduledoc """
  Module for fetching proxy implementation from https://github.com/wighawag/clones-with-immutable-args
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy

  @doc """
  Get implementation address following "Clone with immutable arguments" pattern
  """
  @spec get_implementation_smart_contract(Hash.Address.t(), Keyword.t()) :: SmartContract.t() | nil
  def get_implementation_smart_contract(address_hash, options \\ []) do
    address_hash
    |> get_implementation_address_hash_string(options)
    |> Proxy.implementation_to_smart_contract(options)
  end

  @doc """
  Get implementation address hash string following "Clone with immutable arguments" pattern
  """
  @spec get_implementation_address_hash_string(Hash.Address.t(), Keyword.t()) :: String.t() | nil
  def get_implementation_address_hash_string(address_hash, options \\ []) do
    case Chain.select_repo(options).get(Address, address_hash) do
      nil ->
        nil

      target_address ->
        contract_code = target_address.contract_code

        case contract_code do
          %Chain.Data{bytes: contract_code_bytes} ->
            contract_bytecode = Base.encode16(contract_code_bytes, case: :lower)

            contract_bytecode |> get_proxy_clone_with_immutable_arguments() |> Proxy.abi_decode_address_output()

          _ ->
            nil
        end
    end
  end

  defp get_proxy_clone_with_immutable_arguments(contract_bytecode) do
    case contract_bytecode do
      "3d3d3d3d363d3d3761" <>
          <<_::binary-size(4)>> <>
          "603736393661" <> <<_::binary-size(4)>> <> "013d73" <> <<template_address::binary-size(40)>> <> _ ->
        "0x" <> template_address

      _ ->
        nil
    end
  end
end
