defmodule Indexer.Fetcher.OnDemand.TokenBalance.Supervisor.Case do
  alias Indexer.Fetcher.OnDemand.TokenBalance

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
    |> TokenBalance.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
