defmodule Explorer.Indexer.AddressBalanceFetcherCase do
  alias Explorer.BufferedTask
  alias Explorer.Indexer.AddressBalanceFetcher

  def start_supervised!(options \\ []) when is_list(options) do
    ExUnit.Callbacks.start_supervised!(
      {BufferedTask,
       {AddressBalanceFetcher,
        Keyword.merge(
          [debug_logs: false, fetch_interval: 1, max_batch_size: 1, max_concurrency: 1, name: AddressBalanceFetcher],
          options
        )}}
    )
  end
end
