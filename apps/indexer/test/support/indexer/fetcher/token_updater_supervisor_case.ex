defmodule Indexer.Fetcher.TokenUpdater.Supervisor.Case do
  alias Indexer.Fetcher.TokenUpdater

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    merged_fetcher_arguments =
      Keyword.merge(
        fetcher_arguments,
        flush_interval: 50,
        max_batch_size: 1,
        max_concurrency: 1
      )

    [merged_fetcher_arguments]
    |> TokenUpdater.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
