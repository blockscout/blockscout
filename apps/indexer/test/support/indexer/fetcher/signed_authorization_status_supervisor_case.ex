defmodule Indexer.Fetcher.SignedAuthorizationStatus.Supervisor.Case do
  alias Indexer.Fetcher.SignedAuthorizationStatus

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    merged_fetcher_arguments =
      Keyword.merge(
        fetcher_arguments,
        flush_interval: 50,
        max_batch_size: 2,
        max_concurrency: 2
      )

    [merged_fetcher_arguments]
    |> SignedAuthorizationStatus.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
