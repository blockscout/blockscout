# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Cache.AddressTags do
  @moduledoc """
  Per-address cache for public address tags (`address_tags` joined with
  `address_to_tags`).

  Public tags are read for every address in every transaction, address and
  token-transfer response, but change only through the tag cataloger and the
  admin endpoints, so each address's tag list is cached with a short TTL.
  Addresses without tags are cached too: an empty result is by far the most
  common one, and it is exactly the lookup worth skipping.

  The cache stores whatever list the fallback returns for an address and knows
  nothing about the query itself, so the filtering that the API applies (for
  example hiding the `validator` tag) stays with the caller.
  """

  alias Explorer.Chain.Hash

  @cache_name :address_tags

  @type tag :: %{required(:address_hash) => Hash.Address.t(), optional(atom()) => any()}

  @spec cache_name() :: atom()
  def cache_name, do: @cache_name

  @doc """
  Returns the tags of `address_hashes`, serving addresses already in the cache
  from it and fetching the rest with `fallback_fn` in a single call.

  `fallback_fn` receives the list of address hashes missing from the cache and
  must return the tags of those addresses as maps carrying an `:address_hash`
  key. Every missing address is then cached, including the ones the fallback
  returned no tags for.

  With the cache disabled the fallback is called with all `address_hashes`.
  """
  @spec fetch([Hash.Address.t()], ([Hash.Address.t()] -> [tag()])) :: [tag()]
  def fetch([], _fallback_fn), do: []

  def fetch(address_hashes, fallback_fn) when is_function(fallback_fn, 1) do
    if enabled?() do
      fetch_with_cache(address_hashes, fallback_fn)
    else
      fallback_fn.(address_hashes)
    end
  end

  defp fetch_with_cache(address_hashes, fallback_fn) do
    {cached_tags, missing_hashes} =
      Enum.reduce(address_hashes, {[], []}, fn address_hash, {cached, missing} ->
        case ConCache.get(@cache_name, address_hash) do
          nil -> {cached, [address_hash | missing]}
          tags -> {tags ++ cached, missing}
        end
      end)

    fetched_tags = if missing_hashes == [], do: [], else: fallback_fn.(missing_hashes)
    fetched_by_hash = Enum.group_by(fetched_tags, & &1.address_hash)

    Enum.each(missing_hashes, fn address_hash ->
      ConCache.put(@cache_name, address_hash, %ConCache.Item{
        value: Map.get(fetched_by_hash, address_hash, []),
        ttl: ttl()
      })
    end)

    cached_tags ++ fetched_tags
  end

  defp enabled? do
    config()[:enabled]
  end

  defp ttl do
    config()[:ttl]
  end

  defp config do
    Application.get_env(:explorer, __MODULE__)
  end
end
