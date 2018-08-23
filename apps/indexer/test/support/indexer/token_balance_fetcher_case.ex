defmodule Indexer.TokenBalanceFetcherCase do
  alias Indexer.TokenBalanceFetcher

  def start_supervised!(options \\ []) when is_list(options) do
    options
    |> Keyword.merge(
      flush_interval: 50,
      init_chunk_size: 1,
      max_batch_size: 1,
      max_concurrency: 1,
      name: TokenBalanceFetcher
    )
    |> TokenBalanceFetcher.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
