defmodule Indexer.Fetcher.RootstockData.Supervisor.Case do
  alias Indexer.Fetcher.RootstockData

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    merged_fetcher_arguments =
      Keyword.merge(
        fetcher_arguments,
        interval: 1,
        batch_size: 1,
        max_concurrency: 1
      )

    [merged_fetcher_arguments]
    |> RootstockData.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
