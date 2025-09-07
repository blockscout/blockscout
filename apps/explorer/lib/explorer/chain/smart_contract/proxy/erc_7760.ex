defmodule Explorer.Chain.SmartContract.Proxy.ERC7760 do
  @moduledoc """
  Module for fetching proxy implementation from https://github.com/ethereum/ERCs/blob/master/ERCS/erc-7760.md
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.EIP1967

  @uups_basic_variant "363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e6038573d6000fd5b3d6000f3"
  @uups_l_variant "365814604357363d3d373d3d363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e603e573d6000fd5b3d6000f35b6020600f3d393d51543d52593df3"
  @beacon_basic_variant "363d3d373d3d363d602036600436635c60da1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50545afa5036515af43d6000803e604d573d6000fd5b3d6000f3"
  @beacon_l_variant "363d3d373d3d363d602036600436635c60da1b60e01b36527fa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50545afa361460525736515af43d600060013e6052573d6001fd5b3d6001f3"
  @transparent_basic_variant_20_left "3d3d3373"
  @transparent_basic_variant_20_right "14605757363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e6052573d6000fd5b3d6000f35b3d356020355560408036111560525736038060403d373d3d355af43d6000803e6052573d6000fd"
  @transparent_basic_variant_14_left "3d3d336d"
  @transparent_basic_variant_14_right "14605157363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e604c573d6000fd5b3d6000f35b3d3560203555604080361115604c5736038060403d373d3d355af43d6000803e604c573d6000fd"
  @transparent_l_variant_20_left "3658146083573d3d3373"
  @transparent_l_variant_20_right "14605d57363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e6058573d6000fd5b3d6000f35b3d35602035556040360380156058578060403d373d3d355af43d6000803e6058573d6000fd5b602060293d393d51543d52593df3"
  @transparent_l_variant_14_left "365814607d573d3d336d"
  @transparent_l_variant_14_right "14605757363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc545af43d6000803e6052573d6000fd5b3d6000f35b3d35602035556040360380156052578060403d373d3d355af43d6000803e6052573d6000fd5b602060233d393d51543d52593df3"

  @doc """
  Get implementation address hash string following ERC-7760. It returns the value as array of the strings.
  """
  @spec get_implementation_address_hash_strings(Hash.Address.t()) :: [binary()]
  def get_implementation_address_hash_strings(proxy_address_hash, options \\ []) do
    case get_implementation_address_hash_string(proxy_address_hash, options) do
      nil -> []
      implementation_address_hash_string -> [implementation_address_hash_string]
    end
  end

  # Get implementation address hash string following ERC-7760
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

            contract_bytecode |> get_proxy_erc_7760(proxy_address_hash)

          _ ->
            nil
        end
    end
  end

  # credo:disable-for-next-line /Complexity/
  defp get_proxy_erc_7760(contract_bytecode, proxy_address_hash) do
    case String.downcase(contract_bytecode) do
      @transparent_basic_variant_20_left <>
          <<_factory_address::binary-size(40)>> <> @transparent_basic_variant_20_right <> _ ->
        fetch_implementation(proxy_address_hash)

      @transparent_basic_variant_14_left <>
          <<_factory_address::binary-size(28)>> <> @transparent_basic_variant_14_right <> _ ->
        fetch_implementation(proxy_address_hash)

      @transparent_l_variant_20_left <> <<_factory_address::binary-size(40)>> <> @transparent_l_variant_20_right <> _ ->
        fetch_implementation(proxy_address_hash)

      @transparent_l_variant_14_left <> <<_factory_address::binary-size(28)>> <> @transparent_l_variant_14_right <> _ ->
        fetch_implementation(proxy_address_hash)

      @uups_basic_variant <> _ ->
        fetch_implementation(proxy_address_hash)

      @uups_l_variant <> _ ->
        fetch_implementation(proxy_address_hash)

      @beacon_basic_variant <> _ ->
        fetch_implementation(proxy_address_hash)

      @beacon_l_variant <> _ ->
        fetch_implementation(proxy_address_hash)

      _ ->
        nil
    end
  end

  defp fetch_implementation(proxy_address_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    Proxy.get_implementation_from_storage(
      proxy_address_hash,
      EIP1967.storage_slot_logic_contract_address(),
      json_rpc_named_arguments
    )
  end
end
