defmodule Explorer.Chain.Cache.Accounts do
  @moduledoc """
  Caches the top Addresses
  """

  alias Explorer.Chain.Address

  use Explorer.Chain.OrderedCache,
    name: :accounts,
    max_size: 51,
    preload: :names,
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  @type element :: Address.t()

  @type id :: {non_neg_integer(), non_neg_integer()}

  def element_to_id(%Address{fetched_coin_balance: fetched_coin_balance, hash: hash}) do
    {fetched_coin_balance, hash}
  end

  def prevails?({fetched_coin_balance_a, hash_a}, {fetched_coin_balance_b, hash_b}) do
    # same as a query's `order_by: [desc: :fetched_coin_balance, asc: :hash]`
    if fetched_coin_balance_a == fetched_coin_balance_b do
      hash_a < hash_b
    else
      fetched_coin_balance_a > fetched_coin_balance_b
    end
  end

  def drop(nil), do: :ok

  def drop([]), do: :ok

  def drop(addresses) when is_list(addresses) do
    # This has to be used by the Indexer insead of `update`.
    # The reason being that addresses already in the cache can change their balance
    # value and removing or updating them will result into a potentially invalid
    # cache status, that would not even get corrected with time.
    # The only thing we can safely do when an address in the cache changes its
    # `fetched_coin_balance` is to invalidate the whole cache and wait for it
    # to be filled again (by the query that it takes the place of when full).

    ConCache.update(cache_name(), ids_list_key(), fn ids ->
      if drop_needed?(ids, addresses) do
        # Remove the addresses immediately
        Enum.each(ids, &ConCache.delete(cache_name(), &1))

        {:ok, []}
      else
        {:ok, ids}
      end
    end)
  end

  def drop(address), do: drop([address])

  defp drop_needed?(ids, _addresses) when is_nil(ids), do: false

  defp drop_needed?([], _addresses), do: false

  defp drop_needed?(ids, addresses) do
    ids_map = Map.new(ids, fn {balance, hash} -> {hash, balance} end)

    # Result it `true` only when the address is present in the cache already,
    # but with a different `fetched_coin_balance`
    Enum.find_value(addresses, false, fn address ->
      stored_address_balance = Map.get(ids_map, address.hash)

      stored_address_balance && stored_address_balance != address.fetched_coin_balance
    end)
  end
end
