defmodule Explorer.Chain.Cache.ArbitrumSettlement do
  @moduledoc """
  Cache for Arbitrum rollup settlement data, specifically tracking the highest committed
  and confirmed block numbers.

  This module maintains a cache of two key values:
  - highest_committed_block: The highest L2 block number that has been included in a batch
  - highest_confirmed_block: The highest L2 block number that has been confirmed on the parent chain
  """

  use Explorer.Chain.MapCache,
    name: :arbitrum_settlement,
    keys: [:highest_committed_block, :highest_confirmed_block],
    # The cache is updated when the indexer discovers new batches or confirmations.
    ttl_check_interval: false

  alias Explorer.Chain.Arbitrum.Reader.Indexer.Settlement

  def handle_update(_key, nil, value), do: {:ok, value}

  def handle_update(:highest_committed_block, old_value, new_value), do: {:ok, max(new_value, old_value)}

  def handle_update(:highest_confirmed_block, old_value, new_value), do: {:ok, max(new_value, old_value)}

  # Handles cache misses by fetching block numbers from the database.
  # If query to the database returns nil, returns {:return, nil} to avoid caching nil values.
  # Otherwise returns {:update, value} to cache the fetched value.
  #
  # ## Parameters
  # - `key`: Either `:highest_committed_block` or `:highest_confirmed_block`
  #
  # ## Returns
  # - `{:return, nil}` if the database query returns nil
  # - `{:update, non_neg_integer()}` with the fetched value otherwise
  @spec handle_fallback(:highest_committed_block | :highest_confirmed_block) ::
          {:return, nil} | {:update, non_neg_integer()}
  def handle_fallback(:highest_committed_block) do
    case Settlement.highest_committed_block() do
      nil -> {:return, nil}
      value -> {:update, value}
    end
  end

  def handle_fallback(:highest_confirmed_block) do
    case Settlement.highest_confirmed_block() do
      nil -> {:return, nil}
      value -> {:update, value}
    end
  end
end
