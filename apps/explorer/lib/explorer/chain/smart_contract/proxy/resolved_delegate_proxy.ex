defmodule Explorer.Chain.SmartContract.Proxy.ResolvedDelegateProxy do
  @moduledoc """
  Module for fetching proxy implementation from ResolvedDelegateProxy https://github.com/ethereum-optimism/optimism/blob/9580179013a04b15e6213ae8aa8d43c3f559ed9a/packages/contracts-bedrock/src/legacy/ResolvedDelegateProxy.sol
  """

  alias Explorer.Chain.{Data, Hash}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

  @behaviour ResolverBehaviour

  @resolved_delegate_proxy <<0x608060408181523060009081526001602090815282822054908290529181207FBF40FAC1000000000000000000000000000000000000000000000000000000009093529173FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9091169063BF40FAC19061006D9060846101E2565B602060405180830381865AFA15801561008A573D6000803E3D6000FD5B505050506040513D601F19601F820116820180604052508101906100AE91906102C5565B905073FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF8116610157576040517F08C379A000000000000000000000000000000000000000000000000000000000815260206004820152603960248201527F5265736F6C76656444656C656761746550726F78793A2074617267657420616460448201527F6472657373206D75737420626520696E697469616C697A656400000000000000606482015260840160405180910390FD5B6000808273FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF16600036604051610182929190610302565B600060405180830381855AF49150503D80600081146101BD576040519150601F19603F3D011682016040523D82523D6000602084013E6101C2565B606091505B5090925090508115156001036101DA57805160208201F35B805160208201FD5B600060208083526000845481600182811C91508083168061020457607F831692505B858310810361023A577F4E487B710000000000000000000000000000000000000000000000000000000085526022600452602485FD5B878601838152602001818015610257576001811461028B576102B6565B7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF008616825284151560051B820196506102B6565B60008B81526020902060005B868110156102B057815484820152908501908901610297565B83019750505B50949998505050505050505050565B6000602082840312156102D757600080FD5B815173FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF811681146102FB57600080FD5B9392505050565B818382376000910190815291905056FEA164736F6C634300080F000A::6392>>

  def quick_resolve_implementations(proxy_address, _proxy_type) do
    with {:match, @resolved_delegate_proxy} <-
           {:match, proxy_address.contract_code && proxy_address.contract_code.bytes},
         reqs = get_fetch_requirements(proxy_address.hash),
         {:ok, values} <- Proxy.fetch_values(reqs, proxy_address.hash),
         {:ok, implementation_name} <- extract_short_string(values[reqs |> Enum.at(0)]),
         {:ok, address_manager_address_hash} <- Proxy.extract_address_hash(values[reqs |> Enum.at(1)]),
         {:ok, implementation_value} <-
           Proxy.fetch_value(
             {:call, "0x" <> Base.encode16(ABI.encode("getAddress(string)", [implementation_name]), case: :lower)},
             address_manager_address_hash
           ),
         {:ok, address_hash} <- Proxy.extract_address_hash(implementation_value) do
      {:ok, [address_hash]}
    else
      :error -> :error
      # proceed to other proxy types only if bytecode doesn't match
      {:match, _} -> nil
      # if bytecode matches but resolution fails, we should halt
      _ -> {:ok, []}
    end
  end

  @spec get_fetch_requirements(Hash.Address.t()) :: [ResolverBehaviour.fetch_requirement()]
  def get_fetch_requirements(proxy_address_hash) do
    # slot 0
    # mapping(address => string) private implementationName;
    implementation_name_slot = ExKeccak.hash_256(<<0::96, proxy_address_hash.bytes::binary, 0::256>>)

    # slot 1
    # mapping(address => AddressManager) private addressManager;
    address_manager_slot = ExKeccak.hash_256(<<0::96, proxy_address_hash.bytes::binary, 1::256>>)

    [
      storage: "0x" <> Base.encode16(implementation_name_slot, case: :lower),
      storage: "0x" <> Base.encode16(address_manager_slot, case: :lower)
    ]
  end

  # Decodes string value from smart-contract storage value, works only for short strings (<= 31 bytes)
  @spec extract_short_string(String.t() | nil) :: {:ok, String.t()} | :error | nil
  defp extract_short_string(value) do
    with false <- is_nil(value),
         {:ok, %Data{bytes: bytes}} <- Data.cast(value),
         32 <- byte_size(bytes),
         double_length when double_length > 0 and double_length < 64 <- :binary.last(bytes),
         0 <- rem(double_length, 2) do
      {:ok, binary_part(bytes, 0, div(double_length, 2))}
    else
      :error -> :error
      _ -> nil
    end
  end
end
