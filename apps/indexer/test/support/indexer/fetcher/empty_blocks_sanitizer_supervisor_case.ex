defmodule Indexer.Fetcher.EmptyBlocksSanitizer.Supervisor.Case do
  alias Indexer.Fetcher.EmptyBlocksSanitizer

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    [fetcher_arguments]
    |> EmptyBlocksSanitizer.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
