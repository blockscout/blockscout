# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.CoinBalance.Compactor.Supervisor.Case do
  alias Indexer.Fetcher.CoinBalance.Compactor

  def start_supervised!(fetcher_arguments \\ []) when is_list(fetcher_arguments) do
    [fetcher_arguments]
    |> Compactor.Supervisor.child_spec()
    |> ExUnit.Callbacks.start_supervised!()
  end
end
