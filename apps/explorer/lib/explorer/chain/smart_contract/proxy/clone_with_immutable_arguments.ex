defmodule Explorer.Chain.SmartContract.Proxy.CloneWithImmutableArguments do
  @moduledoc """
  Module for fetching proxy implementation from https://github.com/wighawag/clones-with-immutable-args
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.SmartContract.Proxy

  @doc """
  Get implementation address hash string following "Clone with immutable arguments" proxy pattern. It returns the value as array of the strings.
  """
  @spec get_implementation_address_hash_strings(Hash.Address.t(), [Chain.api?()]) :: [binary()]
  def get_implementation_address_hash_strings(proxy_address_hash, options \\ []) do
    case get_implementation_address_hash_string(proxy_address_hash, options) do
      nil -> []
      implementation_address_hash_string -> [implementation_address_hash_string]
    end
  end

  # Get implementation address hash string following "Clone with immutable arguments" pattern
  @spec get_implementation_address_hash_string(Hash.Address.t(), Keyword.t()) :: binary() | nil
  defp get_implementation_address_hash_string(proxy_address_hash, options) do
    case Chain.select_repo(options).get(Address, proxy_address_hash) do
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
