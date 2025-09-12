defmodule Indexer.Fetcher.Beacon.Deposit.Status.Supervisor.Case do
  alias Indexer.Fetcher.Beacon.Deposit.Status

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    [fetcher_arguments]
    |> Status.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
