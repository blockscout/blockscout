defmodule Indexer.Block.Catchup.Supervisor.Case do
  alias Indexer.Block.Catchup

  def start_supervised!(fetcher_arguments) when is_map(fetcher_arguments) do
    [fetcher_arguments]
    |> Catchup.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
