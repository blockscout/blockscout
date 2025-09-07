defmodule Explorer.Chain.SmartContract.Proxy.EIP2535 do
  @moduledoc """
  Module for fetching proxy implementation from https://eips.ethereum.org/EIPS/eip-2535 (Diamond Proxy)
  """

  alias ABI.TypeDecoder
  alias Explorer.Chain.{Data, Hash}
  alias Explorer.Chain.SmartContract.Proxy.ResolverBehaviour

  @behaviour ResolverBehaviour

  # 0x52ef6b2c = keccak256(facetAddresses())
  @facet_addresses_signature "0x52ef6b2c"

  @max_implementations_number_per_proxy 100

  def quick_resolve_implementations(_proxy_address, _proxy_type),
    do:
      {:cont,
       %{
         implementation_getter: {:call, @facet_addresses_signature}
       }}

  def resolve_implementations(_proxy_address, _proxy_type, prefetched_values) do
    with {:ok, value} <- Map.fetch(prefetched_values, :implementation_getter),
         {:ok, address_hashes} <- extract_address_hashes(value) do
      {:ok, address_hashes}
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
         [all_address_hashes] when is_list(all_address_hashes) <-
           (try do
              TypeDecoder.decode_raw(bytes, [{:array, :address}])
            rescue
              _ -> nil
            end) do
      {:ok,
       all_address_hashes
       |> Enum.reject(&(&1 == <<0::160>>))
       |> Enum.map(&(&1 |> Hash.Address.cast() |> elem(1)))
       |> Enum.take(@max_implementations_number_per_proxy)
       |> Enum.uniq()}
    else
      :error -> :error
      _ -> nil
    end
  end
end
