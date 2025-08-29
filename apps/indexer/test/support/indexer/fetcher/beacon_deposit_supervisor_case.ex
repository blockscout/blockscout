defmodule Indexer.Fetcher.Beacon.Deposit.Supervisor.Case do
  alias Indexer.Fetcher.Beacon.Deposit

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    [fetcher_arguments]
    |> Deposit.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
