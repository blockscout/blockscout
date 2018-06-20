defmodule Explorer.Indexer.InternalTransactionFetcherCase do
  alias Explorer.Indexer.InternalTransactionFetcher

  def start_supervised!(options \\ []) when is_list(options) do
    options
    |> Keyword.put(:name, InternalTransactionFetcher)
    |> InternalTransactionFetcher.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
