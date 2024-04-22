defmodule Indexer.Fetcher.InternalTransaction.Supervisor.Case do
  alias Indexer.Fetcher.InternalTransaction

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    merged_fetcher_arguments =
      Keyword.merge(
        [
          flush_interval: 50,
          max_batch_size: 1,
          max_concurrency: 1,
          poll: false
        ],
        fetcher_arguments
      )

    [merged_fetcher_arguments]
    |> InternalTransaction.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
