defmodule Explorer.Indexer.AddressBalanceFetcherCase do
  alias Explorer.Indexer.AddressBalanceFetcher

  def start_supervised!(options \\ []) when is_list(options) do
    options
    |> Keyword.put(:name, AddressBalanceFetcher)
    |> AddressBalanceFetcher.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
