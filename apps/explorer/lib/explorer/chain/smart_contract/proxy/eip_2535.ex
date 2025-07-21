defmodule Explorer.Chain.SmartContract.Proxy.EIP2535 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-2535 (Diamond Proxy)
  """

  # 0x52ef6b2c = keccak256(facetAddresses())
  @facet_addresses_signature <<0x52EF6B2C::4-unit(8)>>

  @max_implementations_number_per_proxy 100

  alias ABI.TypeDecoder
  alias Explorer.Chain.{Address, Data, Hash}
  alias Explorer.Chain.SmartContract.Proxy

  @spec get_prefetch_requirements(Address.t(), atom()) :: [Proxy.prefetch_requirement()]
  def get_prefetch_requirements(address, _) do
    if address.contract_code && String.contains?(address.contract_code.bytes, @facet_addresses_signature) do
      [call: "0x" <> Base.encode16(@facet_addresses_signature, case: :lower)]
    else
      []
    end
  end

  @doc """
  Get implementation address hash following EIP-2535.
  """
  @spec resolve_implementations(Address.t(), atom(), Proxy.prefetched_values()) :: [Hash.Address.t()] | :error | nil
  def resolve_implementations(proxy_address, proxy_type, prefetched_values) do
    with req when not is_nil(req) <- proxy_address |> get_prefetch_requirements(proxy_type) |> Enum.at(0),
         {:ok, value} <- Proxy.fetch_value(req, proxy_address.hash, prefetched_values),
         {:ok, address_hashes} <- extract_address_hashes(value) do
      address_hashes
    else
      :error -> :error
      _ -> nil
    end
  end

  # Decodes unique non-zero address hashes from raw smart-contract hex response
  @spec extract_address_hashes(String.t() | nil) :: {:ok, [Hash.Address.t()]} | :error | nil
  defp extract_address_hashes(value) do
    with false <- is_nil(value),
         {:ok, %Data{bytes: bytes}} <- Data.cast(value),
         all_address_hashes when is_list(all_address_hashes) <-
           (try do
              TypeDecoder.decode_raw(bytes, [{:array, :address}])
            rescue
              _ -> nil
            end),
         address_hashes =
           all_address_hashes
           |> Enum.reject(&(&1 == <<0::160>>))
           |> Enum.map(&(&1 |> Hash.Address.cast() |> elem(1)))
           |> Enum.take(@max_implementations_number_per_proxy)
           |> Enum.uniq(),
         false <- Enum.empty?(address_hashes) do
      {:ok, address_hashes}
    else
      :error -> :error
      _ -> nil
    end
  end
end
