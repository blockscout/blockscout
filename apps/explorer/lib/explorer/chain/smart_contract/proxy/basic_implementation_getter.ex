defmodule Explorer.Chain.SmartContract.Proxy.BasicImplementationGetter do
  @moduledoc """
  Module for fetching proxy implementation from public smart-contract method
  """

  # 5c60da1b = keccak256(implementation())
  @implementation_signature <<0x5C60DA1B::4-unit(8)>>
  # aaf10f42 = keccak256(getImplementation())
  @get_implementation_signature <<0xAAF10F42::4-unit(8)>>
  # bb82aa5e = keccak256(comptrollerImplementation())
  @comptroller_implementation_signature <<0xBB82AA5E::4-unit(8)>>

  alias Explorer.Chain.{Address, Hash}
  alias Explorer.Chain.SmartContract.Proxy

  @spec get_prefetch_requirements(Address.t(), :implementation | :get_implementation | :comptroller_implementation) ::
          [Proxy.prefetch_requirement()]
  def get_prefetch_requirements(address, proxy_type) do
    signature =
      case proxy_type do
        :implementation -> @implementation_signature
        :get_implementation -> @get_implementation_signature
        :comptroller_implementation -> @comptroller_implementation_signature
        _ -> nil
      end

    if signature && address.contract_code && String.contains?(address.contract_code.bytes, signature) do
      [call: "0x" <> Base.encode16(signature, case: :lower)]
    else
      []
    end
  end

  @doc """
  Get implementation address hash from public smart-contract method.
  """
  @spec resolve_implementations(Address.t(), atom(), Proxy.prefetched_values()) :: [Hash.Address.t()] | :error | nil
  def resolve_implementations(proxy_address, proxy_type, prefetched_values) do
    with req when not is_nil(req) <- proxy_address |> get_prefetch_requirements(proxy_type) |> Enum.at(0),
         {:ok, value} <- Proxy.fetch_value(req, proxy_address.hash, prefetched_values),
         {:ok, address_hash} <- Proxy.extract_address_hash(value) do
      [address_hash]
    else
      :error -> :error
      _ -> nil
    end
  end
end
