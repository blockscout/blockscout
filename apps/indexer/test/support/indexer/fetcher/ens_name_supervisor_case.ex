defmodule Indexer.Fetcher.ENSName.Supervisor.Case do
  alias Indexer.Fetcher.ENSName

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    merged_fetcher_arguments =
      Keyword.merge(
        fetcher_arguments,
        flush_interval: 300,
        max_batch_size: 1,
        max_concurrency: 100
      )

    [merged_fetcher_arguments]
    |> ENSName.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
