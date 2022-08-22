defmodule Indexer.Fetcher.EventProcessor.Supervisor.Case do
  alias Indexer.Fetcher.EventProcessor

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    [fetcher_arguments]
    |> EventProcessor.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
