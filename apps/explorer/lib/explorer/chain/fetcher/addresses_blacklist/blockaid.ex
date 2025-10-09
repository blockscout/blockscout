defmodule Explorer.Chain.Fetcher.AddressesBlacklist.Blockaid do
  @moduledoc """
  Fetcher for addresses blacklist from blockaid provider
  """
  alias Explorer.{Chain, HttpClient}
  alias Explorer.Chain.Fetcher.AddressesBlacklist

  @behaviour AddressesBlacklist

  @keys_to_blacklist ["OFAC", "Malicious"]
  @timeout 60_000

  @impl AddressesBlacklist
  def fetch_addresses_blacklist do
    case HttpClient.get(AddressesBlacklist.url(), [], recv_timeout: @timeout, timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        body
        |> Jason.decode()
        |> parse_blacklist()

      _ ->
        MapSet.new()
    end
  end

  defp parse_blacklist({:ok, json}) when is_map(json) do
    @keys_to_blacklist
    |> Enum.reduce([], fn key, acc ->
      acc ++
        (json
         |> Map.get(key, [])
         |> Enum.map(fn address_hash_string ->
           address_hash_or_nil = Chain.string_to_address_hash_or_nil(address_hash_string)
           address_hash_or_nil && {address_hash_or_nil, nil}
         end)
         |> Enum.reject(&is_nil/1))
    end)
    |> MapSet.new()
  end

  defp parse_blacklist({:error, _}) do
    MapSet.new()
  end
end
